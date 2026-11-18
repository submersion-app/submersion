#!/usr/bin/env python3
"""Megalodon, FathomNet's detector of any marine organism, prepared for the
accuracy scorer (the measured accuracy design,
docs/design/specs/2026-11-17-marine-life-identification-measured-accuracy-design.md).

    python -I tool/species_pack/megalodon.py convert megalodon-2024 --check-image PHOTO
    python -I tool/species_pack/megalodon.py check megalodon-2024 --tool TOOL PHOTO...

Fetches the pinned checkpoints, opens them with torch's safe loader and an
allowlist of the layer classes they hold, and converts them to 16-bit Core
ML with a tensor input like the pack's other models. The app's Swift
pipeline runs them through its `yolo` detector format.

Needs requirements.txt plus the `ultralytics` package, which is AGPL-3.0 and
used here offline only, to define the layers. Developer-run; not part of CI,
the app build or a pack.
"""

import argparse
import copy
import hashlib
import json
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import boxes as box_math  # noqa: E402
import manifest as pack_manifest  # noqa: E402

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DEFAULT_WORK = os.path.join(REPO, "build", "species_accuracy_work")

CHECKPOINTS = {
    "megalodon-2024": {
        "repo": "FathomNet/megalodon-2024-yolov11",
        "revision": "403704d2d4dba9903ffbdd215648c3fc8ae6f377",
        "file": "mbari-megalodon-yolo11x.pt",
        "sha256": "27ab91d07fa61d6ae1af9a2c18e29d6b89044254aec7d38b1a4331cbb9b3a450",
        "id": "megalodon-yolo11x-403704d",
    },
}
# The checkpoint a pack carries.
PACK_CHECKPOINT = "megalodon-2024"
# Not here: FathomNet/megalodon-2023-yolov8 (YOLOv8x). Its checkpoint was
# saved with dill and needs dill's general type loader to open, which the
# safe loader rightly refuses.

# How Megalodon is run, by the scorer and in a pack: the ultralytics
# defaults, kept in manifest.py with the pack's other detector.
SETTINGS = copy.deepcopy(pack_manifest.DETECTORS["megalodon"])
SUPPRESS_IOU = 0.7
LETTERBOX_GREY = 114


def fetch(name):
    """The checkpoint's local path, checked against its pinned hash."""
    from huggingface_hub import hf_hub_download

    spec = CHECKPOINTS[name]
    path = hf_hub_download(spec["repo"], spec["file"], revision=spec["revision"])
    digest = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b""):
            digest.update(chunk)
    if digest.hexdigest() != spec["sha256"]:
        raise SystemExit(f"{name}: checkpoint hash does not match the pinned one")
    return path


def load(name):
    """The detection model in export mode: one output, [1, 4 + classes,
    anchors], boxes as centre and size in input pixels, scores already
    squashed. Opened with the safe loader, allowing only the layer classes
    the checkpoint names, so unpickling cannot run other code."""
    import torch
    from ultralytics.nn.modules.head import Detect

    path = fetch(name)
    allowed = []
    for qualified in torch.serialization.get_unsafe_globals_in_checkpoint(path):
        module, _, attr = qualified.rpartition(".")
        cls = None
        if module.startswith(("torch.nn.modules.", "ultralytics.")):
            cls = getattr(__import__(module, fromlist=[attr]), attr, None)
        # Only torch modules: the safe loader rebuilds them from their
        # saved state without calling anything else.
        if not (isinstance(cls, type) and issubclass(cls, torch.nn.Module)):
            raise SystemExit(f"{name}: checkpoint names {qualified}, which is not a torch module")
        allowed.append(cls)
    with torch.serialization.safe_globals(allowed):
        checkpoint = torch.load(path, map_location="cpu", weights_only=True)
    model = (checkpoint.get("ema") or checkpoint["model"]).float().fuse().eval()
    for m in model.modules():
        if isinstance(m, Detect):
            m.export = True
            m.format = "coreml"
    return model


def letterbox(image, size):
    """`image` (PIL) letterboxed into a `size` square as ultralytics does:
    scaled to fit, centred, padded with grey 114. Returns the [1, 3, size,
    size] float array scaled 0 to 1, and (scale x, scale y, left, top)."""
    import numpy as np
    from PIL import Image

    w, h = image.size
    r = min(size / w, size / h)
    nw, nh = round(w * r), round(h * r)
    left, top = round((size - nw) / 2 - 0.1), round((size - nh) / 2 - 0.1)
    canvas = Image.new("RGB", (size, size), (LETTERBOX_GREY,) * 3)
    canvas.paste(image.convert("RGB").resize((nw, nh), Image.BILINEAR), (left, top))
    x = (np.asarray(canvas, dtype=np.float32) / 255).transpose(2, 0, 1)[None]
    return x, (nw / w, nh / h, left, top)


def reference_boxes(model, image, size=640):
    """Boxes from the PyTorch model through ultralytics' own letterbox,
    suppression and mapping back, normalised 0 to 1 against `image` (an
    upright PIL image), best first. None of this module's own geometry is
    used, so a mistake shared with the Swift side cannot hide."""
    import numpy as np
    import torch
    from ultralytics.data.augment import LetterBox
    from ultralytics.utils import nms, ops

    rgb = np.asarray(image.convert("RGB"))
    boxed = LetterBox(new_shape=(size, size), auto=False)(image=rgb)
    x = torch.from_numpy(np.ascontiguousarray(boxed.transpose(2, 0, 1))[None].astype(np.float32) / 255)
    with torch.no_grad():
        out = model(x)
    kept = nms.non_max_suppression(
        out, conf_thres=SETTINGS["scoreThreshold"], iou_thres=SUPPRESS_IOU, max_det=SETTINGS["maxBoxes"]
    )[0]
    kept[:, :4] = ops.scale_boxes((size, size), kept[:, :4], rgb.shape[:2])
    h, w = rgb.shape[:2]
    found = []
    for x0, y0, x1, y1, score, _ in kept.tolist():
        x0, x1, y0, y1 = x0 / w, x1 / w, y0 / h, y1 / h
        found.append({"x": x0, "y": y0, "w": x1 - x0, "h": y1 - y0, "score": score})
    return found


def convert(name, work, check_image):
    """`<work>/models/<name>/detector.mlpackage`, 16-bit, iOS 15, checked
    against the PyTorch model on `check_image`."""
    import coremltools as ct
    import numpy as np
    import torch
    from PIL import Image

    model = load(name)
    size = SETTINGS["inputSize"]
    x, _ = letterbox(Image.open(check_image), size)
    example = torch.from_numpy(x)
    with torch.no_grad():
        reference = model(example).numpy()
    traced = torch.jit.trace(model, example, strict=False)
    ml = ct.convert(
        traced,
        inputs=[ct.TensorType(name="image", shape=example.shape)],
        minimum_deployment_target=ct.target.iOS15,
        compute_precision=ct.precision.FLOAT16,
        convert_to="mlprogram",
    )
    out_dir = os.path.join(work, "models", name)
    os.makedirs(out_dir, exist_ok=True)
    target = os.path.join(out_dir, "detector.mlpackage")
    # A model compiled from an earlier conversion would be picked up in
    # preference to the new package; remove it with the old package.
    for old in (target, os.path.join(out_dir, "detector.mlmodelc")):
        if os.path.exists(old):
            shutil.rmtree(old)
    ml.save(target)

    got = np.asarray(next(iter(ml.predict({"image": x}).values())), dtype=np.float32)
    ref_scores, got_scores = reference[0, 4:].max(0), got[0, 4:].max(0)
    if ref_scores.max() < 0.25:
        raise SystemExit(f"{name}: nothing found in the check image; choose one with an animal in it")
    drift = float(np.abs(np.sort(got_scores)[::-1][:10] - np.sort(ref_scores)[::-1][:10]).max())
    best_ref, best_got = reference[0, :4, ref_scores.argmax()], got[0, :4, got_scores.argmax()]
    overlap = box_math.iou(
        (best_ref[0] - best_ref[2] / 2, best_ref[1] - best_ref[3] / 2, best_ref[2], best_ref[3]),
        (best_got[0] - best_got[2] / 2, best_got[1] - best_got[3] / 2, best_got[2], best_got[3]),
    )
    print(f"{name}: score drift {drift:.4f}, best box overlap {overlap:.3f}")
    if drift > 0.05 or overlap < 0.9:
        raise SystemExit(f"{name}: converted detector differs from the original")
    return target


def converted_dir(work, name):
    """The folder holding the converted detector in `work`, or a stop that
    says how to make it: `convert` is a separate step, since it needs a
    check image and several minutes."""
    folder = os.path.join(work, "models", name)
    if not any(os.path.exists(os.path.join(folder, f"detector.{ext}")) for ext in ("mlpackage", "mlmodelc")):
        raise SystemExit(
            f"{name} is not converted in {work}; run "
            f"`python -I tool/species_pack/megalodon.py convert {name} --work {work} --check-image PHOTO` first"
        )
    return folder


def _stamp(package):
    """What identifies a converted package: each file's path, size and
    modification time."""
    entries = []
    for root, _, files in os.walk(package):
        for name in sorted(files):
            full = os.path.join(root, name)
            info = os.stat(full)
            entries.append([os.path.relpath(full, package), info.st_size, info.st_mtime_ns])
    return sorted(entries)


def converted_stamp(work, name):
    """What identifies the converted model in `work`: its package's stamp,
    or the compiled model's when the folder holds only that."""
    folder = converted_dir(work, name)
    package = os.path.join(folder, "detector.mlpackage")
    return _stamp(package if os.path.exists(package) else os.path.join(folder, "detector.mlmodelc"))


def tool_model(work, name):
    """Megalodon's model to hand the vision tool, which compiles a model
    package once and deletes it: a copy of the converted package (or the
    copy's compiled model), so the package itself stays for build_pack.py.
    A folder converted before copies were made holds only a compiled model,
    which is handed over as it is."""
    folder = converted_dir(work, name)
    package = os.path.join(folder, "detector.mlpackage")
    if not os.path.exists(package):
        return os.path.join(folder, "detector.mlmodelc")
    copy_dir = os.path.join(work, "models", f"{name}-tool")
    stamp_path = os.path.join(copy_dir, "source.json")
    stamp = _stamp(package)
    stored = None
    if os.path.exists(stamp_path):
        with open(stamp_path, encoding="utf-8") as fh:
            stored = json.load(fh)
    if stored != stamp and os.path.exists(copy_dir):
        shutil.rmtree(copy_dir)
    compiled = os.path.join(copy_dir, "detector.mlmodelc")
    copy = os.path.join(copy_dir, "detector.mlpackage")
    if os.path.exists(compiled):
        return compiled
    if not os.path.exists(copy):
        shutil.copytree(package, copy)
        with open(stamp_path, "w", encoding="utf-8") as fh:
            json.dump(stamp, fh)
    return copy


def manifest_for_settings(base):
    """A copy of the pack manifest `base` carrying Megalodon alone, for the
    vision tool."""
    return pack_manifest.with_detectors(base, [SETTINGS], pack_manifest.BOXES)


def manifest_for(name, pack_manifest_path):
    """The pack manifest at `pack_manifest_path` with Megalodon `name` as
    its only detector, for the vision tool."""
    if CHECKPOINTS[name]["id"] != SETTINGS["id"]:
        raise SystemExit(f"{name} is not the Megalodon the pack settings describe")
    with open(pack_manifest_path, encoding="utf-8") as fh:
        return manifest_for_settings(json.load(fh))


def check(name, tool, manifest_path, classifier, photos, work):
    """The share of the reference boxes on `photos` that the vision tool's
    yolo path matches at an intersection over union of 0.9 or more."""
    from PIL import Image, ImageOps

    model = load(name)
    run = subprocess.run(
        [
            tool,
            "--manifest",
            manifest_path,
            "--detector",
            tool_model(work, name),
            "--classifier",
            classifier,
            "--crop-fit",
            "padSquare",
        ],
        input="\n".join(photos) + "\n",
        capture_output=True,
        text=True,
        check=True,
    )
    matched = total = 0
    for line, photo in zip(run.stdout.splitlines(), photos):
        result = json.loads(line)
        ours = [(d["x"], d["y"], d["w"], d["h"]) for d in result.get("detections", [])]
        # Upright, as the Swift side decodes it.
        for ref in reference_boxes(model, ImageOps.exif_transpose(Image.open(photo))):
            total += 1
            rect = (ref["x"], ref["y"], ref["w"], ref["h"])
            if any(box_math.iou(rect, o) >= 0.9 for o in ours):
                matched += 1
    share = matched / total if total else 0.0
    print(f"{name}: {matched} of {total} reference boxes matched ({share:.0%})")
    return share


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("action", choices=["convert", "check"])
    parser.add_argument("name", choices=sorted(CHECKPOINTS))
    parser.add_argument("photos", nargs="*")
    parser.add_argument("--work", default=DEFAULT_WORK)
    parser.add_argument("--check-image")
    parser.add_argument("--tool")
    parser.add_argument("--pack", help="a pack folder, for its manifest")
    parser.add_argument("--classifier", help="a compiled or packaged classifier model")
    args = parser.parse_args(argv)
    if args.action == "convert":
        if not args.check_image:
            parser.error("convert needs --check-image")
        convert(args.name, args.work, args.check_image)
        return 0
    if not (args.tool and args.pack and args.classifier and args.photos):
        parser.error("check needs --tool, --pack, --classifier and photos")
    manifest_path = os.path.join(args.work, "models", args.name, "manifest.json")
    with open(manifest_path, "w", encoding="utf-8") as fh:
        json.dump(manifest_for(args.name, os.path.join(args.pack, "manifest.json")), fh)
    share = check(args.name, args.tool, manifest_path, args.classifier, args.photos, args.work)
    return 0 if share >= 0.9 else 1


if __name__ == "__main__":
    sys.exit(main())
