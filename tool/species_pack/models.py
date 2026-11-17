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

CLASSIFIER_HUB = "hf-hub:imageomics/bioclip-2"
CLASSIFIER_REVISION = "2957b322090f9cb17ae72c71981c7218a28d81e0"
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
    """The detector as a 16-bit Core ML model package."""
    from rfdetr import from_checkpoint

    model = from_checkpoint(checkpoint)
    produced = model.export(
        output_dir=out_dir, format="coreml", coreml_precision="float16", verbose=False
    )
    target = os.path.join(out_dir, "detector.mlpackage")
    if os.path.exists(target):
        shutil.rmtree(target)
    shutil.move(str(produced), target)
    return target


def _classifier():
    import open_clip

    model, _, preprocess = open_clip.create_model_and_transforms(CLASSIFIER_HUB)
    tokenizer = open_clip.get_tokenizer(CLASSIFIER_HUB)
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
