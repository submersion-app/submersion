#!/usr/bin/env python3
"""Fetches the two published models, converts them for the app's engines,
and embeds candidate names with the classifier's text tower. The settings
are the spike's (spec appendix); change them only with a new model id.
Needs requirements.txt."""

import hashlib
import os
import shutil
import urllib.request
import zipfile

DETECTOR_URL = (
    "https://github.com/filippovarini/community-fish-detector/releases/download/"
    "2026.07.06-release/cfd-rf-detr-nano-640-2026.02.02.cp-011.20260706-release.pth"
)
DETECTOR_SHA256 = "e3eac301b778e251c3826eae247cc783e1f2dab3fd71a18de92bf3e8999c6f10"
DETECTOR_ID = "cfd-rfdetr-nano-640-20260706"

CLASSIFIER_REPO = "imageomics/bioclip-2"
CLASSIFIER_REVISION = "2957b322090f9cb17ae72c71981c7218a28d81e0"
CLASSIFIER_WEIGHTS = "open_clip_model.safetensors"
CLASSIFIER_WEIGHTS_SHA256 = "b7b2bf6fbc95799e42630e394cf95803892ab447c1a8ab629dbc82fbeaf7dfef"
CLASSIFIER_ID = "bioclip-2-vitl14-2957b32"
EMBEDDING_SIZE = 768

USER_AGENT = "species-pack-builder/0.1 (+https://github.com/submersion-app/submersion)"


def _sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def fetch_detector(work):
    path = os.path.join(work, "detector.pth")
    if not os.path.exists(path) or _sha256(path) != DETECTOR_SHA256:
        request = urllib.request.Request(DETECTOR_URL, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=600) as response, open(path, "wb") as out:
            shutil.copyfileobj(response, out)
    if _sha256(path) != DETECTOR_SHA256:
        raise SystemExit("detector checkpoint hash does not match the pinned one")
    # The checkpoint must hold only tensors and plain data.
    import torch

    torch.load(path, map_location="cpu", weights_only=True)
    return path


def convert_detector(checkpoint, out_dir):
    """The detector as a 16-bit Core ML model package, checked against the
    original on a fixed scene."""
    from rfdetr import from_checkpoint

    model = from_checkpoint(checkpoint)
    produced = model.export(
        output_dir=out_dir, format="coreml", coreml_precision="float16", verbose=False
    )
    target = os.path.join(out_dir, "detector.mlpackage")
    if os.path.exists(target):
        shutil.rmtree(target)
    shutil.move(str(produced), target)
    check_detector(model, target)
    return target


def _test_scene():
    """Blue water with two fish shapes, 640 pixels square: the detector
    must find at least one, so the comparison is never of noise."""
    from PIL import Image, ImageDraw

    image = Image.new("RGB", (640, 640), (20, 90, 160))
    draw = ImageDraw.Draw(image)
    draw.ellipse((120, 200, 360, 300), fill=(230, 200, 60))
    draw.polygon([(360, 250), (420, 210), (420, 290)], fill=(230, 200, 60))
    draw.ellipse((380, 420, 560, 490), fill=(200, 80, 60))
    draw.polygon([(380, 455), (330, 425), (330, 485)], fill=(200, 80, 60))
    return image


def _iou(a, b):
    ix = max(0.0, min(a[2], b[2]) - max(a[0], b[0]))
    iy = max(0.0, min(a[3], b[3]) - max(a[1], b[1]))
    inter = ix * iy
    union = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter
    return inter / union if union > 0 else 0.0


def check_detector(model, package):
    """Compares the converted detector with the original on the test scene:
    the ten best scores, sorted (queries with near-equal scores may swap
    places between runtimes), and the best box."""
    import coremltools as ct
    import numpy as np

    scene = _test_scene()
    reference = model.predict(scene, threshold=0.0)
    ref_scores = np.sort(np.asarray(reference.confidence))[::-1]
    if ref_scores[0] < 0.5:
        raise SystemExit("the detector finds no fish in the test scene; cannot compare")

    mean = np.array([0.485, 0.456, 0.406])
    std = np.array([0.229, 0.224, 0.225])
    x = ((np.asarray(scene, dtype=np.float32) / 255 - mean) / std).transpose(2, 0, 1)[None]
    converted = ct.models.MLModel(package)
    input_name = converted.get_spec().description.input[0].name
    outputs = [np.asarray(v) for v in converted.predict({input_name: x.astype(np.float32)}).values()]
    boxes = next(v for v in outputs if v.shape[-1] == 4).reshape(-1, 4)
    logits = next(v for v in outputs if v.shape[-1] != 4)
    scores = 1 / (1 + np.exp(-logits.reshape(boxes.shape[0], -1).max(axis=1)))

    drift = float(np.abs(np.sort(scores)[::-1][:10] - ref_scores[:10]).max())
    cx, cy, w, h = boxes[int(scores.argmax())] * 640
    overlap = _iou(
        (cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2),
        reference.xyxy[int(np.argmax(reference.confidence))],
    )
    if drift > 0.05 or overlap < 0.9:
        raise SystemExit(
            f"converted detector differs from the original (score drift {drift:.4f}, box overlap {overlap:.3f})"
        )


def _classifier_dir():
    """The classifier's files at the pinned revision, with the weights
    checked against their pinned hash."""
    from huggingface_hub import snapshot_download

    path = snapshot_download(
        CLASSIFIER_REPO,
        revision=CLASSIFIER_REVISION,
        allow_patterns=["open_clip_config.json", CLASSIFIER_WEIGHTS],
    )
    if _sha256(os.path.join(path, CLASSIFIER_WEIGHTS)) != CLASSIFIER_WEIGHTS_SHA256:
        raise SystemExit("classifier weights hash does not match the pinned one")
    return path


def _classifier():
    import open_clip

    source = "local-dir:" + _classifier_dir()
    model, _, preprocess = open_clip.create_model_and_transforms(source)
    tokenizer = open_clip.get_tokenizer(source)
    return model.eval(), preprocess, tokenizer


def convert_classifier(out_dir):
    """The image tower as a 16-bit Core ML model package, checked against
    the original on a fixed input."""
    import coremltools as ct
    import numpy as np
    import torch

    model, _, _ = _classifier()
    visual = model.visual.eval()
    torch.manual_seed(0)
    x = torch.rand(1, 3, 224, 224)
    with torch.no_grad():
        ref = visual(x).numpy()
    traced = torch.jit.trace(visual, x, strict=False)
    ml = ct.convert(
        traced,
        inputs=[ct.TensorType(name="image", shape=x.shape)],
        minimum_deployment_target=ct.target.iOS15,
        compute_precision=ct.precision.FLOAT16,
        convert_to="mlprogram",
    )
    target = os.path.join(out_dir, "classifier.mlpackage")
    if os.path.exists(target):
        shutil.rmtree(target)
    ml.save(target)
    got = np.asarray(next(iter(ml.predict({"image": x.numpy()}).values())), dtype=np.float32)
    ref, got = ref.ravel(), got.ravel()
    cosine = float(ref @ got / (np.linalg.norm(ref) * np.linalg.norm(got)))
    if cosine < 0.999:
        raise SystemExit(f"converted classifier differs from the original (cosine {cosine:.5f})")
    return target


def text_embeddings(candidates):
    """One unit-length 768-wide row per candidate: the mean of three prompts,
    as the spike used."""
    import numpy as np
    import torch

    model, _, tokenizer = _classifier()
    device = "mps" if torch.backends.mps.is_available() else "cpu"
    model = model.to(device)
    rows = []
    with torch.no_grad():
        for c in candidates:
            sci, common = c["scientificName"], c["commonName"]
            prompts = [
                f"a photo of {sci}.",
                f"a photo of {common}.",
                f"a photo of {sci} with common name {common}.",
            ]
            e = model.encode_text(tokenizer(prompts).to(device))
            e = e / e.norm(dim=-1, keepdim=True)
            m = e.mean(dim=0)
            rows.append((m / m.norm()).cpu().numpy())
    return np.stack(rows).astype(np.float16)


def zip_model(package_dir, dest_zip):
    """Zips a model package with its own folder at the top, as the app's
    installer expects."""
    base = os.path.dirname(package_dir)
    with zipfile.ZipFile(dest_zip, "w", zipfile.ZIP_DEFLATED) as zf:
        for root, _, files in os.walk(package_dir):
            for name in sorted(files):
                full = os.path.join(root, name)
                zf.write(full, os.path.relpath(full, base))
    return dest_zip
