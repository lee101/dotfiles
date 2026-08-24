"""Command-line interface for querying RTX 5090 GPU pricing across providers."""

from __future__ import annotations

import argparse
import json
import os
import sys
from typing import Iterable, List, Optional, Sequence

if __package__ in (None, "", __name__):  # pragma: no cover - runtime convenience
    sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
    from gpuhosting.providers import (  # type: ignore[import-self]
        ProviderAuthError,
        ProviderAvailabilityError,
        ProviderError,
        ProviderQuote,
        ProviderResponseError,
        fetch_runpod_quote,
        fetch_tensordock_quote,
        fetch_vast_quote,
    )
else:
    from .providers import (  # pragma: no cover - normal package import path
        ProviderAuthError,
        ProviderAvailabilityError,
        ProviderError,
        ProviderQuote,
        ProviderResponseError,
        fetch_runpod_quote,
        fetch_tensordock_quote,
        fetch_vast_quote,
    )


SUPPORTED_PROVIDERS = ("tensordock", "runpod", "vast")


def parse_args(argv: Optional[Sequence[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Compare RTX 5090 pricing across GPU hosting providers."
    )
    parser.add_argument(
        "--gpu",
        default="RTX 5090",
        help="GPU model to search (default: RTX 5090).",
    )
    parser.add_argument(
        "--providers",
        default="all",
        help="Comma-separated providers to query (tensordock, runpod, vast).",
    )
    parser.add_argument(
        "--format",
        choices=("table", "json"),
        default="table",
        help="Output format (default: table).",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=15.0,
        help="HTTP timeout per request in seconds.",
    )
    parser.add_argument(
        "--min-vcpus",
        type=int,
        default=2,
        help="Minimum vCPUs to include for TensorDock price estimation (default: 2).",
    )
    parser.add_argument(
        "--min-ram-gb",
        type=int,
        default=4,
        help="Minimum RAM (GB) to include for TensorDock price estimation (default: 4).",
    )
    parser.add_argument(
        "--min-storage-gb",
        type=int,
        default=20,
        help="Minimum storage (GB) to include for TensorDock price estimation (default: 20).",
    )
    parser.add_argument(
        "--vast-market",
        choices=("on-demand", "interruptible"),
        default="on-demand",
        help="Vast.ai market type to query (default: on-demand).",
    )
    parser.add_argument(
        "--vast-limit",
        type=int,
        default=50,
        help="Maximum Vast.ai offers to inspect (default: 50).",
    )
    parser.add_argument(
        "--gpu-count",
        type=int,
        default=1,
        help="GPU count for RunPod pricing (default: 1).",
    )
    return parser.parse_args(argv)


def resolve_providers(selection: str) -> List[str]:
    if selection.strip().lower() in ("all", "*"):
        return list(SUPPORTED_PROVIDERS)

    requested = [item.strip().lower() for item in selection.split(",") if item.strip()]
    invalid = [item for item in requested if item not in SUPPORTED_PROVIDERS]
    if invalid:
        raise SystemExit(f"Unsupported providers: {', '.join(invalid)}.")
    deduped = []
    for provider in requested:
        if provider not in deduped:
            deduped.append(provider)
    return deduped


def collect_quotes(
    providers: Iterable[str],
    *,
    gpu: str,
    timeout: float,
    min_vcpus: int,
    min_ram_gb: int,
    min_storage_gb: int,
    gpu_count: int,
    vast_market: str,
    vast_limit: int,
) -> tuple[List[ProviderQuote], List[str]]:
    quotes: List[ProviderQuote] = []
    errors: List[str] = []

    for provider in providers:
        try:
            if provider == "tensordock":
                quote = fetch_tensordock_quote(
                    gpu_name=gpu,
                    min_vcpus=min_vcpus,
                    min_ram_gb=min_ram_gb,
                    min_storage_gb=min_storage_gb,
                    timeout=timeout,
                )
            elif provider == "runpod":
                quote = fetch_runpod_quote(
                    gpu_name=gpu,
                    gpu_count=gpu_count,
                    timeout=timeout,
                )
            elif provider == "vast":
                quote = fetch_vast_quote(
                    gpu_name=gpu,
                    market=vast_market,
                    limit=vast_limit,
                    timeout=timeout,
                )
            else:
                errors.append(f"Unknown provider '{provider}'.")
                continue
            quotes.append(quote)
        except (ProviderAuthError, ProviderAvailabilityError, ProviderResponseError) as exc:
            errors.append(str(exc))
        except ProviderError as exc:
            errors.append(str(exc))
        except Exception as exc:  # pragma: no cover - defensive safety
            errors.append(f"{provider}: unexpected error: {exc}")

    quotes.sort(key=lambda q: (q.hourly_total if q.hourly_total is not None else float("inf")))
    return quotes, errors


def render_table(quotes: List[ProviderQuote], errors: List[str]) -> None:
    if not quotes:
        print("No pricing data available.")
        if errors:
            print()
            print("Errors:")
            for err in errors:
                print(f"  - {err}")
        return

    cheapest = quotes[0]
    print(f"Cheapest GPU host: {cheapest.provider} (${cheapest.hourly_total:.4f}/hr)")
    print()
    for quote in quotes:
        marker = "*" if quote is cheapest else " "
        price = f"${quote.hourly_total:.4f}/hr" if quote.hourly_total is not None else "n/a"
        label = f"{marker} {quote.provider:<11} {price}"
        if quote.price_type:
            label += f" ({quote.price_type})"
        print(label)
        breakdown_items = [
            f"{component}=${value:.4f}/hr"
            for component, value in quote.price_breakdown.items()
            if value
        ]
        if breakdown_items:
            print(f"    breakdown: {', '.join(breakdown_items)}")
        if quote.location:
            print(f"    location: {quote.location}")
        if quote.offer_reference:
            print(f"    offer id: {quote.offer_reference}")
        if quote.availability:
            print(f"    availability: {quote.availability}")
        if quote.notes:
            for note in quote.notes:
                print(f"    note: {note}")
        print()

    if errors:
        print("Errors:")
        for err in errors:
            print(f"  - {err}")


def render_json(quotes: List[ProviderQuote], errors: List[str]) -> None:
    payload = {
        "cheapest_provider": quotes[0].provider if quotes else None,
        "quotes": [quote.to_dict() for quote in quotes],
        "errors": errors,
    }
    json.dump(payload, sys.stdout, indent=2)
    sys.stdout.write("\n")


def main(argv: Optional[Sequence[str]] = None) -> None:
    args = parse_args(argv)
    providers = resolve_providers(args.providers)
    quotes, errors = collect_quotes(
        providers,
        gpu=args.gpu,
        timeout=args.timeout,
        min_vcpus=args.min_vcpus,
        min_ram_gb=args.min_ram_gb,
        min_storage_gb=args.min_storage_gb,
        gpu_count=args.gpu_count,
        vast_market=args.vast_market,
        vast_limit=args.vast_limit,
    )

    if args.format == "json":
        render_json(quotes, errors)
    else:
        render_table(quotes, errors)


if __name__ == "__main__":  # pragma: no cover
    main()
