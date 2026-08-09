"""Provider-specific helpers for fetching GPU pricing quotes."""

from __future__ import annotations

import json
import os
import ssl
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass, field
from typing import Any, Dict, Iterable, List, Optional, Tuple


class ProviderError(Exception):
    """Base class for provider-specific exceptions."""

    def __init__(self, provider: str, message: str) -> None:
        super().__init__(message)
        self.provider = provider
        self.message = message

    def __str__(self) -> str:  # pragma: no cover - simple formatting helper
        return f"{self.provider}: {self.message}"


class ProviderAuthError(ProviderError):
    """Raised when an API key or token is missing."""


class ProviderAvailabilityError(ProviderError):
    """Raised when no matching offers are available."""


class ProviderResponseError(ProviderError):
    """Raised when the upstream API returns an error response."""


@dataclass
class ProviderQuote:
    """Normalized provider quote."""

    provider: str
    gpu_name: str
    hourly_total: Optional[float]
    currency: str = "USD"
    price_breakdown: Dict[str, float] = field(default_factory=dict)
    location: Optional[str] = None
    price_type: Optional[str] = None
    availability: Optional[str] = None
    offer_reference: Optional[str] = None
    metadata: Dict[str, Any] = field(default_factory=dict)
    notes: List[str] = field(default_factory=list)

    def to_dict(self) -> Dict[str, Any]:
        """Return a JSON-serializable representation."""
        return {
            "provider": self.provider,
            "gpu_name": self.gpu_name,
            "hourly_total": self.hourly_total,
            "currency": self.currency,
            "price_breakdown": self.price_breakdown,
            "location": self.location,
            "price_type": self.price_type,
            "availability": self.availability,
            "offer_reference": self.offer_reference,
            "metadata": self.metadata,
            "notes": self.notes,
        }


def _build_request(
    url: str,
    *,
    headers: Optional[Dict[str, str]] = None,
    method: str = "GET",
    data: Optional[bytes] = None,
    timeout: float = 15.0,
) -> urllib.request.Request:
    req = urllib.request.Request(url, data=data, headers=headers or {})
    req.method = method
    req.timeout = timeout  # type: ignore[attr-defined]
    return req


def _json_request(req: urllib.request.Request) -> Any:
    try:
        with urllib.request.urlopen(req, context=ssl.create_default_context()) as resp:
            body = resp.read().decode("utf-8")
            if not body:
                return None
            return json.loads(body)
    except urllib.error.HTTPError as exc:  # pragma: no cover - network errors
        try:
            error_body = exc.read().decode("utf-8")
        except Exception:  # pragma: no cover
            error_body = ""
        raise ProviderResponseError(req.full_url, f"HTTP {exc.code}: {error_body}") from exc
    except urllib.error.URLError as exc:  # pragma: no cover - network errors
        raise ProviderResponseError(req.full_url, f"Network error: {exc}") from exc


def _normalize_gpu_matches(name: str) -> List[str]:
    lowered = "".join(ch for ch in name.lower() if ch.isalnum())
    return [lowered]


def _matches_gpu(target: str, candidates: Iterable[Optional[str]]) -> bool:
    scarified = _normalize_gpu_matches(target)
    for cand in candidates:
        if not cand:
            continue
        diff = "".join(ch for ch in cand.lower() if ch.isalnum())
        if all(token in diff for token in scarified):
            return True
    return False


def _to_float(value: Any) -> Optional[float]:
    if value is None:
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def _format_location(parts: Iterable[Optional[str]]) -> Optional[str]:
    formatted = ", ".join(part for part in parts if part)
    return formatted or None


def fetch_tensordock_quote(
    *,
    gpu_name: str,
    min_vcpus: int,
    min_ram_gb: int,
    min_storage_gb: int,
    timeout: float = 15.0,
) -> ProviderQuote:
    token = (
        os.getenv("TENSORDOCK_API_TOKEN")
        or os.getenv("TENSORDOCK_API_KEY")
        or os.getenv("TENSOR_DOCK_AUTH")
    )
    if not token:
        raise ProviderAuthError("TensorDock", "Set TENSORDOCK_API_TOKEN (or TENSORDOCK_API_KEY).")

    url = "https://dashboard.tensordock.com/api/v2/locations"
    headers = {
        "Authorization": f"Bearer {token}",
        "Accept": "application/json",
    }
    req = _build_request(url, headers=headers, timeout=timeout)
    try:
        payload = _json_request(req)
    except ProviderResponseError as exc:
        raise ProviderResponseError("TensorDock", exc.message) from exc

    locations: List[Dict[str, Any]] = []
    if isinstance(payload, dict):
        data = payload.get("data")
        if isinstance(data, dict) and isinstance(data.get("locations"), list):
            locations = data["locations"]
        elif isinstance(data, list):
            locations = data
        elif isinstance(payload.get("locations"), list):
            locations = payload["locations"]  # type: ignore[assignment]

    best_quote: Optional[ProviderQuote] = None

    for location in locations:
        gpus = location.get("gpus") or []
        for gpu in gpus:
            if not _matches_gpu(gpu_name, (gpu.get("displayName"), gpu.get("v0Name"))):
                continue

            gpu_price = _to_float(gpu.get("price_per_hr"))
            pricing = gpu.get("pricing") or {}
            per_vcpu = _to_float(pricing.get("per_vcpu_hr"))
            per_ram = _to_float(pricing.get("per_gb_ram_hr"))
            per_storage = _to_float(pricing.get("per_gb_storage_hr"))

            breakdown: Dict[str, float] = {}
            estimated_total: Optional[float] = gpu_price

            def _accumulate(label: str, count: int, rate: Optional[float]) -> None:
                nonlocal estimated_total
                if count <= 0 or rate is None:
                    return
                component_cost = rate * count
                breakdown[label] = component_cost
                if estimated_total is None:
                    estimated_total = component_cost
                else:
                    estimated_total += component_cost

            breakdown["gpu"] = gpu_price or 0.0
            _accumulate("cpu", min_vcpus, per_vcpu)
            _accumulate("ram", min_ram_gb, per_ram)
            _accumulate("storage", min_storage_gb, per_storage)

            location_label = _format_location(
                (
                    location.get("city"),
                    location.get("stateprovince"),
                    location.get("country"),
                )
            )

            quote = ProviderQuote(
                provider="TensorDock",
                gpu_name=gpu.get("displayName") or gpu_name,
                hourly_total=estimated_total,
                price_breakdown=breakdown,
                location=location_label,
                offer_reference=location.get("id"),
                metadata={"raw_gpu_entry": gpu},
            )

            stock_status = gpu.get("stock_status") or gpu.get("stockStatus")
            if stock_status:
                quote.availability = stock_status

            if per_vcpu is None or per_ram is None or per_storage is None:
                quote.notes.append("Per-resource pricing missing; totals may exclude some costs.")

            if best_quote is None:
                best_quote = quote
            else:
                best_val = best_quote.hourly_total or float("inf")
                current_val = quote.hourly_total or float("inf")
                if current_val < best_val:
                    best_quote = quote

    if best_quote is None:
        raise ProviderAvailabilityError(
            "TensorDock", f"No offers matched GPU '{gpu_name}'."
        )
    return best_quote


def _runpod_query(
    *,
    api_key: str,
    gpu_identifier: str,
    gpu_count: int,
    timeout: float,
) -> Dict[str, Any]:
    query = """
        query CheapestQuote($input: GpuTypeFilter!, $gpuCount: Int!) {
          gpuTypes(input: $input) {
            id
            displayName
            lowestPrice(input: { gpuCount: $gpuCount }) {
              minimumBidPrice
              uninterruptablePrice
              stockStatus
              maxUnreservedGpuCount
            }
            communityPrice
            securePrice
            communitySpotPrice
            secureSpotPrice
            communityCloud
            secureCloud
          }
        }
    """
    variables = {"input": {"id": gpu_identifier}, "gpuCount": gpu_count}
    payload_bytes = json.dumps({"query": query, "variables": variables}).encode("utf-8")
    quoted_key = urllib.parse.quote(api_key)
    url = f"https://api.runpod.io/graphql?api_key={quoted_key}"
    headers = {"Content-Type": "application/json"}
    req = _build_request(url, headers=headers, data=payload_bytes, method="POST", timeout=timeout)
    try:
        data = _json_request(req)
    except ProviderResponseError as exc:
        raise ProviderResponseError("RunPod", exc.message) from exc
    if not isinstance(data, dict) or "data" not in data:
        raise ProviderResponseError("RunPod", "Unexpected response shape.")
    return data


def fetch_runpod_quote(
    *,
    gpu_name: str,
    gpu_count: int = 1,
    timeout: float = 15.0,
) -> ProviderQuote:
    api_key = os.getenv("RUNPOD_API_KEY")
    if not api_key:
        raise ProviderAuthError("RunPod", "Set RUNPOD_API_KEY.")

    candidate_ids: Tuple[str, ...]
    normalized = gpu_name.strip()
    if normalized.lower().startswith("nvidia"):
        candidate_ids = (normalized,)
    else:
        candidate_ids = (
            normalized,
            f"NVIDIA {normalized}",
            f"NVIDIA GeForce {normalized}",
        )

    errors: List[str] = []
    result_payload: Optional[Dict[str, Any]] = None

    for candidate in candidate_ids:
        try:
            result_payload = _runpod_query(
                api_key=api_key,
                gpu_identifier=candidate,
                gpu_count=gpu_count,
                timeout=timeout,
            )
        except ProviderResponseError as exc:
            errors.append(str(exc))
            continue

        gpu_types = result_payload.get("data", {}).get("gpuTypes") if result_payload else None
        if gpu_types:
            break

    if not result_payload:
        raise ProviderResponseError("RunPod", "; ".join(errors) or "Failed to query RunPod API.")

    gpu_types = result_payload.get("data", {}).get("gpuTypes")
    if not gpu_types:
        raise ProviderAvailabilityError("RunPod", f"No GPU type '{gpu_name}' found.")

    gpu_entry = gpu_types[0]
    lowest = gpu_entry.get("lowestPrice") or {}
    spot_price = _to_float(lowest.get("minimumBidPrice"))
    on_demand = _to_float(lowest.get("uninterruptablePrice"))
    candidates = [(spot_price, "spot-bid"), (on_demand, "on-demand")]

    cheapest_price: Optional[float] = None
    selected_type: Optional[str] = None
    for price, price_type in candidates:
        if price is None:
            continue
        if cheapest_price is None or price < cheapest_price:
            cheapest_price = price
            selected_type = price_type

    if cheapest_price is None:
        raise ProviderAvailabilityError("RunPod", f"No pricing available for '{gpu_name}'.")

    price_breakdown = {}
    if spot_price is not None:
        price_breakdown["spot_bid"] = spot_price
    if on_demand is not None:
        price_breakdown["on_demand"] = on_demand

    availability = lowest.get("stockStatus")
    remaining_count = lowest.get("maxUnreservedGpuCount")
    if isinstance(remaining_count, (int, float)):
        availability = f"{availability or 'stock'} (≤{int(remaining_count)} GPUs)"

    quote = ProviderQuote(
        provider="RunPod",
        gpu_name=gpu_entry.get("displayName") or gpu_name,
        hourly_total=cheapest_price,
        price_breakdown=price_breakdown,
        price_type=selected_type,
        availability=availability,
        metadata={
            "communityPrice": gpu_entry.get("communityPrice"),
            "securePrice": gpu_entry.get("securePrice"),
            "communitySpotPrice": gpu_entry.get("communitySpotPrice"),
            "secureSpotPrice": gpu_entry.get("secureSpotPrice"),
            "raw_gpu_entry": gpu_entry,
        },
    )

    if selected_type == "spot-bid":
        quote.notes.append("Spot pricing requires bidding and may be preempted.")

    return quote


def _build_vast_payload(
    gpu_name: str,
    market_type: str,
    limit: int,
) -> Tuple[Dict[str, Any], List[str]]:
    candidates = [
        gpu_name.replace(" ", "_"),
        gpu_name,
    ]
    seen: set[str] = set()
    normalized_candidates = []
    for candidate in candidates:
        candidate = candidate.strip()
        if not candidate:
            continue
        if candidate in seen:
            continue
        seen.add(candidate)
        normalized_candidates.append(candidate)
    payload = {
        "q": {
            "verified": {"eq": True},
            "rentable": {"eq": True},
            "rented": {"eq": False},
        },
        "order": [["dph_total", "asc"]],
        "limit": limit,
        "type": market_type,
        "disable_bundling": True,
        "select_cols": [
            "id",
            "gpu_name",
            "num_gpus",
            "dph_total",
            "cpu_cores_effective",
            "cpu_ram",
            "disk_space",
            "geolocation",
            "reliability2",
            "min_bid",
            "max_bid",
            "inet_up",
            "inet_down",
            "direct_port_count",
        ],
    }
    payload["q"]["gpu_name"] = {"eq": normalized_candidates[0]}
    return payload, normalized_candidates


def fetch_vast_quote(
    *,
    gpu_name: str,
    market: str = "on-demand",
    limit: int = 50,
    timeout: float = 15.0,
) -> ProviderQuote:
    api_key = os.getenv("VAST_API_KEY")
    if not api_key:
        raise ProviderAuthError("Vast.ai", "Set VAST_API_KEY.")

    payload, candidates = _build_vast_payload(gpu_name, market, limit)
    url = "https://console.vast.ai/api/v0/search/asks/"
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    payload_bytes = json.dumps(payload).encode("utf-8")
    req = _build_request(url, headers=headers, data=payload_bytes, method="PUT", timeout=timeout)
    try:
        response = _json_request(req)
    except ProviderResponseError as exc:
        raise ProviderResponseError("Vast.ai", exc.message) from exc

    offers = response.get("offers") if isinstance(response, dict) else None
    if not offers:
        if len(candidates) > 1:
            # retry with raw string if initial underscore form failed
            payload["q"]["gpu_name"] = {"eq": candidates[-1]}
            payload_bytes = json.dumps(payload).encode("utf-8")
            req = _build_request(url, headers=headers, data=payload_bytes, method="PUT", timeout=timeout)
            try:
                response = _json_request(req)
            except ProviderResponseError as exc:
                raise ProviderResponseError("Vast.ai", exc.message) from exc
            offers = response.get("offers") if isinstance(response, dict) else None

    if not offers:
        raise ProviderAvailabilityError("Vast.ai", f"No offers matched GPU '{gpu_name}'.")

    offer = offers[0]
    total_price = _to_float(offer.get("dph_total"))
    if total_price is None:
        raise ProviderAvailabilityError("Vast.ai", "Offer missing price information.")

    location = offer.get("geolocation")
    if isinstance(location, dict):
        location = location.get("city") or location.get("country")

    price_breakdown = {"gpu_total": total_price}
    metadata = {
        "num_gpus": offer.get("num_gpus"),
        "cpu_cores_effective": offer.get("cpu_cores_effective"),
        "cpu_ram": offer.get("cpu_ram"),
        "disk_space": offer.get("disk_space"),
        "reliability2": offer.get("reliability2"),
        "inet_up": offer.get("inet_up"),
        "inet_down": offer.get("inet_down"),
        "direct_port_count": offer.get("direct_port_count"),
        "min_bid": offer.get("min_bid"),
        "max_bid": offer.get("max_bid"),
        "raw_offer": offer,
    }

    quote = ProviderQuote(
        provider="Vast.ai",
        gpu_name=offer.get("gpu_name") or gpu_name,
        hourly_total=total_price,
        price_breakdown=price_breakdown,
        location=location,
        price_type=market,
        offer_reference=str(offer.get("id")) if offer.get("id") is not None else None,
        metadata=metadata,
    )

    reliability = offer.get("reliability2")
    if reliability is not None:
        quote.availability = f"reliability {reliability}"

    if market != "on-demand":
        quote.notes.append("Interruptible market pricing may be reclaimed by host.")

    min_bid = _to_float(offer.get("min_bid"))
    if min_bid is not None and min_bid > total_price:
        quote.notes.append(f"Minimum bid ${min_bid:.4f}/hr may apply.")

    return quote
