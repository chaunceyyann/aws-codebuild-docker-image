#!/usr/bin/env python3
import argparse
import sys
import yaml
import os

def parse_args():
    parser = argparse.ArgumentParser(
        description="Validate one or more YAML files according to optional 'validation' rules."
    )
    parser.add_argument(
        "--file",
        nargs="+",
        required=True,
        help="YAML files to validate (shell globbing is fine, e.g. image-recipes/*)"
    )
    return parser.parse_args()

def get_nested(data, path):
    """Retrieve a value from nested dicts via dot-notation, or None."""
    curr = data
    for key in path.split("."):
        if not isinstance(curr, dict) or key not in curr:
            return None
        curr = curr[key]
    return curr

def validate_file(path):
    errs = []
    # 1) YAML syntax
    try:
        with open(path) as f:
            data = yaml.safe_load(f)
    except Exception as e:
        errs.append(f"YAML syntax error: {e}")
        return errs

    # 2) Optional 'validation' section
    meta = data.get("validation", {})
    # required_fields
    for field in meta.get("required_fields", []):
        if get_nested(data, field) is None:
            errs.append(f"Missing required field: '{field}'")
    # allowed_base_images
    allowed = meta.get("allowed_base_images")
    if allowed:
        base = get_nested(data, "image.base_image")
        if base not in allowed:
            errs.append(f"Base image '{base}' not in allowed list {allowed}")
    # min_dependencies
    min_dep = meta.get("min_dependencies")
    deps = get_nested(data, "dependencies.python")
    if isinstance(deps, list) and isinstance(min_dep, int):
        if len(deps) < min_dep:
            errs.append(
                f"Only {len(deps)} python deps, but min_dependencies is {min_dep}"
            )

    return errs

def main():
    args = parse_args()
    overall_fail = False

    for filepath in args.file:
        # skip directories
        if os.path.isdir(filepath):
            continue

        print(f"=== Validating: {filepath} ===")
        errors = validate_file(filepath)
        if errors:
            overall_fail = True
            for e in errors:
                print(f"ERROR: {e}")
        else:
            print("OK")

    sys.exit(1 if overall_fail else 0)

if __name__ == "__main__":
    main() 