#!/usr/bin/env python3
"""Lead parsers for the national hyperbaric registries that publish a list.

Every row produced here is a LEAD, marked verified.via == "registry". Leads are
confirmed against the facility's own website before they reach the shipped
dataset. None of these sources grants a redistribution license, which is why
the pipeline re-verifies rather than republishes.

Extraction is text-based rather than DOM-selector-based: these pages are
hand-maintained and their markup churns while their visible text does not.

SPUMS (Australia and New Zealand) is deliberately not parsed here. Its page is
flat prose with no record delimiter: unit names, clinicians' names, and several
labelled phone numbers per unit run together, and a parser cannot reliably bind
a number to the facility it belongs to. A trial parser attached the national
Diver Emergency Service hotline to a named hospital unit and a clinician's name
to another unit's switchboard. Wrong numbers in an emergency directory are
worse than missing ones, so those twelve units are hand-curated in
scripts/data/chambers_overlay.json instead.
"""

import html
import re
import unicodedata

TAG_RE = re.compile(r"<[^>]+>")
WHITESPACE_RE = re.compile(r"[ \t\xa0]+")


def visible_text(markup):
    """Strip markup to visible text, preserving line structure so records stay
    separable."""
    text = re.sub(r"(?is)<(script|style).*?</\1>", " ", markup)
    text = re.sub(r"(?i)<(br|/p|/div|/li|/tr|/h[1-6])\s*/?>", "\n", text)
    text = TAG_RE.sub(" ", text)
    text = html.unescape(text)
    text = unicodedata.normalize("NFC", text)
    text = WHITESPACE_RE.sub(" ", text)
    return [line.strip() for line in text.split("\n") if line.strip()]


# Countries whose subscriber numbers keep the leading zero after the country
# code. Italy is the notable one: +39 0832 335499 is correct and +39 832 335499
# does not connect.
TRUNK_ZERO_KEPT = {"39"}

# E.164 allows at most 15 digits including the country code.
MAX_E164_DIGITS = 15


def normalize_phone(raw, default_country_code):
    """Normalize to a leading-plus international number.

    A national-format number is promoted using the country's dialing code. The
    leading trunk zero is dropped for countries that drop it and kept for those
    that do not (see [TRUNK_ZERO_KEPT]). A parenthesised trunk zero after an
    international prefix ("+64-(0)9-487 2214") is always dropped, since it is an
    instruction to domestic callers rather than part of the number.

    Registry pages routinely list two numbers on one line separated by nothing
    more than a space, so tokens are accumulated only while the result stays a
    plausible single number.
    """
    if not raw:
        return None
    cleaned = raw.replace("(0)", "")
    match = re.search(r"(?:\+|00)?[\d][\d\s\-.()]{5,}", cleaned)
    if not match:
        return None

    # Accumulate space-separated groups until another would overflow E.164,
    # which is what a second number on the same line looks like.
    digits = ""
    for token in match.group(0).split():
        candidate = digits + re.sub(r"[^\d+]", "", token)
        if len(candidate.lstrip("+")) > MAX_E164_DIGITS and digits:
            break
        digits = candidate
    if not digits:
        return None

    if digits.startswith("00"):
        digits = "+" + digits[2:]
    if digits.startswith("+"):
        return digits
    if default_country_code not in TRUNK_ZERO_KEPT:
        digits = digits.lstrip("0")
    if not digits:
        return None
    return f"+{default_country_code}{digits}"


def normalize_dashes(value):
    """Replace en and em dashes with a plain hyphen.

    Registry pages punctuate facility names with typographic dashes; the
    project forbids them in any committed text, and a hyphen reads identically
    in a facility name.
    """
    if value is None:
        return None
    return value.replace("—", "-").replace("–", "-")


def slugify(value):
    value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode()
    value = re.sub(r"[^a-zA-Z0-9]+", "-", value).strip("-").lower()
    return re.sub(r"-{2,}", "-", value)


def make_id(country, name):
    return f"{country.lower()}-{slugify(name)}"[:60]


def lead_row(
    *,
    country,
    name,
    phone,
    city=None,
    emergency_phone=None,
    capability="unknown",
    availability="unknown",
    source_url,
    retrieved,
):
    """Build a lead row. Coordinates are filled by geocoding in the build step,
    so they are absent here."""
    name = normalize_dashes(name.strip())
    city = normalize_dashes(city.strip()) if city else None
    row = {
        "id": make_id(country, name),
        "name": name,
        "country": country,
        "city": city,
        "phone": phone,
        "capability": capability,
        "availability": availability,
        "verified": {"date": retrieved, "via": "registry", "url": source_url},
    }
    if emergency_phone:
        row["emergencyPhone"] = emergency_phone
    return row


def _field(lines, label):
    """Value of a `Label: value` line, or None when absent or blank.

    SIMSI publishes the labels for every centre and fills the values in for
    only some, so a blank value means "not stated", never "no".
    """
    pattern = re.compile(rf"^{label}\s*:?\s*(.*)$", re.IGNORECASE)
    for line in lines:
        match = pattern.match(line)
        if match:
            value = match.group(1).strip(" /")
            return value or None
    return None


def parse_simsi(markup, *, retrieved, source_url):
    """SIMSI publishes one labelled block per Italian centre.

    The emergency flag has two spellings on the same page, "Urgenza h24: SI"
    and "Urgenze h24 no". Matching on the bare string "h24" would read the
    second, which says no, as a 24-hour emergency chamber.
    """
    lines = visible_text(markup)
    starts = [
        i for i, line in enumerate(lines) if line.lower().startswith("denominazione")
    ]
    rows = []

    for index, start in enumerate(starts):
        end = starts[index + 1] if index + 1 < len(starts) else len(lines)
        record = lines[start:end]

        name = _field(record, "Denominazione")
        if not name:
            continue
        phone = normalize_phone(_field(record, "Recapito telefonico"), "39")
        if not phone:
            continue

        urgenza = _field(record, "Urgenza h24")
        explicit_no = any(
            re.search(r"urgenze?\s+h24\s+no", line, re.IGNORECASE) for line in record
        )
        if urgenza and re.search(r"\bs[iì]\b", urgenza, re.IGNORECASE):
            capability, availability = "diving_emergency", "h24"
        elif explicit_no or (urgenza and re.search(r"\bno\b", urgenza, re.IGNORECASE)):
            capability, availability = "hyperbaric_unit", "business_hours"
        else:
            capability, availability = "unknown", "unknown"

        rows.append(
            lead_row(
                country="IT",
                name=name,
                city=_field(record, "Citt.")
                or _field(record, "Città"),
                phone=phone,
                capability=capability,
                availability=availability,
                source_url=source_url,
                retrieved=retrieved,
            )
        )

    return rows


def parse_bha(markup, *, retrieved, source_url):
    """The British Hyperbaric Association lists members as city, name, address,
    switchboard, emergency line, terminated by a "Chamber status:" line."""
    lines = visible_text(markup)
    boundaries = [
        i for i, line in enumerate(lines) if line.lower().startswith("chamber status")
    ]
    rows = []
    start = 0

    for boundary in boundaries:
        record = lines[start:boundary]
        status = lines[boundary]
        start = boundary + 1
        if len(record) < 3:
            continue

        city, name = record[0], record[1]
        phones = [line for line in record if re.match(r"^\(?0\d[\d\s()-]{6,}", line)]
        if not phones:
            continue

        emergency = next((p for p in phones if "emergenc" in p.lower()), None)
        switchboard = next((p for p in phones if "emergenc" not in p.lower()), phones[0])

        # A facility the association reports as off-service is not somewhere to
        # send a diver, so its capability is recorded as unknown rather than
        # implied by membership.
        operational = "fully operational" in status.lower()

        rows.append(
            lead_row(
                country="GB",
                name=name,
                city=city,
                phone=normalize_phone(switchboard, "44"),
                emergency_phone=normalize_phone(emergency, "44") if emergency else None,
                capability="hyperbaric_unit" if operational else "unknown",
                availability="on_call" if emergency else "unknown",
                source_url=source_url,
                retrieved=retrieved,
            )
        )

    return [row for row in rows if row["phone"]]


def parse_ffessm(pdf_text, *, retrieved, source_url):
    """The FFESSM list is a PDF whose records terminate with "Caisson civil" or
    "Caisson militaire". The city precedes the facility's address block.

    This list is visibly old: the phone formats predate the current French
    numbering conventions in places. Every row is a lead to re-verify.
    """
    lines = [line.strip() for line in pdf_text.split("\n") if line.strip()]
    rows = []
    record = []

    for line in lines:
        lowered = line.lower()
        if lowered.startswith("caisson civil") or lowered.startswith(
            "caisson militaire"
        ):
            military = lowered.startswith("caisson militaire")
            # The record is: city, then bullet-prefixed address lines, then a
            # phone line. The bullet survives text extraction as \x80.
            city = None
            name = None
            for entry in record:
                stripped = entry.lstrip("\x80 ").strip()
                if entry.startswith("\x80") and name is None:
                    name = stripped
                elif not entry.startswith("\x80") and not entry.lower().startswith(
                    "tél"
                ):
                    if city is None and not re.match(r"^\d{5}", stripped):
                        city = stripped
            phone_line = next(
                (e for e in record if e.lower().startswith("tél")), None
            )
            phone = normalize_phone(phone_line, "33")
            record = []
            if not name or not phone:
                continue
            rows.append(
                lead_row(
                    country="FR",
                    name=name,
                    city=city,
                    phone=phone,
                    # Military chambers open to the public only in emergencies.
                    availability="on_call" if military else "unknown",
                    capability="hyperbaric_unit",
                    source_url=source_url,
                    retrieved=retrieved,
                )
            )
            continue

        if lowered.startswith("zone ") or lowered.startswith("\x80 zone"):
            record = []
            continue
        record.append(line)

    return rows
