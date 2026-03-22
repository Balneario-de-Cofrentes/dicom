#!/usr/bin/env python3
"""
Scrape DICOM PS3.16 Context Groups (CIDs) from the official NEMA standard.

Parses HTML tables from https://dicom.nema.org/medical/dicom/current/output/chtml/part16/
and outputs priv/context_groups.json for use by mix dicom.gen_context_groups.

Usage:
    python3 scripts/scrape_context_groups.py
    python3 scripts/scrape_context_groups.py --output priv/context_groups.json
    python3 scripts/scrape_context_groups.py --workers 5
"""

import argparse
import json
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from urllib.request import urlopen, Request
from urllib.error import HTTPError, URLError

BASE_URL = "https://dicom.nema.org/medical/dicom/current/output/chtml/part16"

# All CID numbers from PS3.16 table of contents
ALL_CIDS = [
    2, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 18, 19, 20, 21, 23, 25, 26, 27,
    29, 30, 31, 32, 33, 34, 42, 43, 44, 50, 60, 61, 62, 63, 64, 65, 66, 67,
    68, 69, 70, 71, 72, 73, 74, 75, 76, 82, 83, 84, 85, 91, 92, 93, 94,
    100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 210, 211, 212, 217,
    218, 219, 220, 221, 222, 223, 224, 225, 226, 227, 228, 230, 231, 240,
    241, 242, 244, 245, 246, 247, 250, 251, 252, 270, 271, 272, 280, 281,
    300, 301, 400, 401, 402, 403, 404, 405, 406, 501, 502, 601, 602, 603,
    604, 605, 606, 607, 608, 609, 610, 611, 612, 613, 614, 615, 616, 617,
    618, 619, 620, 621, 622, 623, 624, 625, 626, 627, 628, 629, 630, 631,
    632, 633, 634, 635, 636, 637, 638, 639, 640, 641, 642, 643, 644, 645,
    646, 647, 701, 702, 703, 800, 900, 901, 1000, 1001, 1002, 1003, 1004,
    1005, 1006, 1010, 1011, 1015, 1200, 1201, 3000, 3001, 3003, 3004, 3005,
    3010, 3011, 3014, 3015, 3016, 3019, 3020, 3021, 3022, 3030, 3031, 3032,
    3033, 3034, 3035, 3036, 3037, 3038, 3039, 3040, 3041, 3042, 3043, 3044,
    3045, 3046, 3047, 3048, 3049, 3050, 3082, 3083, 3090, 3101, 3102, 3104,
    3106, 3107, 3108, 3110, 3111, 3112, 3113, 3114, 3115, 3116, 3117, 3118,
    3119, 3120, 3121, 3122, 3200, 3201, 3202, 3203, 3204, 3205, 3206, 3207,
    3208, 3209, 3210, 3211, 3212, 3213, 3215, 3217, 3220, 3221, 3227, 3228,
    3229, 3230, 3231, 3232, 3233, 3234, 3235, 3236, 3237, 3238, 3239, 3240,
    3241, 3250, 3254, 3261, 3262, 3263, 3264, 3271, 3335, 3337, 3339, 3400,
    3401, 3402, 3403, 3404, 3405, 3406, 3407, 3408, 3409, 3410, 3411, 3412,
    3413, 3414, 3415, 3416, 3418, 3419, 3421, 3422, 3423, 3425, 3426, 3427,
    3428, 3429, 3430, 3440, 3441, 3442, 3446, 3448, 3451, 3452, 3453, 3455,
    3456, 3458, 3460, 3461, 3462, 3463, 3465, 3466, 3467, 3468, 3469, 3470,
    3471, 3472, 3480, 3481, 3482, 3483, 3484, 3485, 3486, 3487, 3488, 3489,
    3491, 3492, 3493, 3494, 3495, 3496, 3497, 3500, 3502, 3503, 3510, 3515,
    3520, 3524, 3525, 3526, 3527, 3528, 3529, 3530, 3531, 3550, 3551, 3552,
    3553, 3554, 3555, 3560, 3600, 3602, 3604, 3606, 3607, 3608, 3609, 3610,
    3611, 3612, 3613, 3614, 3615, 3616, 3617, 3618, 3619, 3620, 3621, 3627,
    3628, 3629, 3630, 3640, 3641, 3642, 3651, 3663, 3664, 3666, 3667, 3668,
    3670, 3671, 3672, 3673, 3675, 3676, 3677, 3678, 3679, 3680, 3681, 3682,
    3683, 3684, 3685, 3686, 3687, 3688, 3689, 3690, 3691, 3692, 3700, 3701,
    3703, 3704, 3705, 3706, 3707, 3709, 3710, 3711, 3712, 3713, 3714, 3715,
    3716, 3717, 3718, 3719, 3720, 3721, 3722, 3723, 3724, 3726, 3727, 3728,
    3729, 3730, 3733, 3735, 3736, 3737, 3738, 3739, 3740, 3741, 3742, 3743,
    3744, 3745, 3746, 3747, 3748, 3749, 3750, 3752, 3754, 3755, 3756, 3757,
    3758, 3760, 3761, 3762, 3764, 3769, 3770, 3772, 3773, 3774, 3777, 3778,
    3779, 3780, 3781, 3782, 3783, 3784, 3785, 3802, 3804, 3805, 3806, 3807,
    3808, 3809, 3810, 3813, 3814, 3815, 3817, 3820, 3821, 3823, 3826, 3827,
    3829, 3831, 3832, 3833, 3835, 3836, 3837, 3838, 3839, 3840, 3843, 3850,
    4005, 4009, 4010, 4011, 4012, 4013, 4014, 4015, 4016, 4017, 4018, 4019,
    4020, 4021, 4025, 4026, 4028, 4029, 4030, 4031, 4032, 4033, 4040, 4042,
    4050, 4051, 4052, 4053, 4061, 4062, 4063, 4064, 4065, 4066, 4067, 4068,
    4069, 4070, 4071, 4072, 4100, 4101, 4102, 4103, 4104, 4105, 4106, 4107,
    4108, 4109, 4110, 4111, 4200, 4201, 4202, 4203, 4204, 4205, 4206, 4207,
    4208, 4209, 4210, 4211, 4214, 4215, 4216, 4220, 4221, 4222, 4230, 4231,
    4232, 4233, 4234, 4235, 4236, 4237, 4238, 4239, 4240, 4241, 4242, 4243,
    4244, 4245, 4250, 4251, 4252, 4253, 4254, 4255, 4256, 4257, 4260, 4261,
    4262, 4263, 4264, 4265, 4266, 4267, 4268, 4270, 4271, 4272, 4273, 4274,
    4275, 4280, 4281, 4282, 4283, 4284, 4285, 4286, 4287, 4288, 4289, 4290,
    4291, 4401, 4402, 4403, 4404, 4405, 4406, 4407, 4408, 4409, 4410, 4411,
    4412, 5000, 5001, 5002, 6000, 6001, 6002, 6003, 6004, 6005, 6006, 6007,
    6008, 6009, 6010, 6011, 6012, 6013, 6014, 6015, 6016, 6017, 6018, 6019,
    6020, 6021, 6022, 6023, 6024, 6025, 6026, 6027, 6028, 6029, 6030, 6031,
    6032, 6033, 6034, 6035, 6036, 6037, 6038, 6039, 6040, 6041, 6042, 6043,
    6044, 6045, 6046, 6047, 6048, 6050, 6051, 6052, 6053, 6054, 6055, 6056,
    6057, 6058, 6059, 6060, 6061, 6062, 6063, 6064, 6065, 6066, 6067, 6068,
    6069, 6070, 6071, 6072, 6080, 6081, 6082, 6083, 6084, 6085, 6086, 6087,
    6088, 6089, 6090, 6091, 6092, 6093, 6094, 6095, 6096, 6097, 6098, 6099,
    6100, 6101, 6102, 6103, 6104, 6105, 6106, 6107, 6108, 6109, 6110, 6111,
    6112, 6113, 6114, 6115, 6116, 6117, 6118, 6119, 6120, 6121, 6122, 6123,
    6124, 6125, 6126, 6127, 6128, 6129, 6130, 6131, 6132, 6133, 6134, 6135,
    6136, 6137, 6138, 6139, 6140, 6141, 6142, 6143, 6144, 6145, 6146, 6147,
    6148, 6149, 6151, 6152, 6153, 6154, 6155, 6157, 6158, 6159, 6160, 6161,
    6162, 6163, 6164, 6165, 6166, 6170, 6171, 6200, 6201, 6202, 6203, 6204,
    6205, 6206, 6207, 6208, 6209, 6210, 6211, 6212, 6300, 6301, 6302, 6303,
    6304, 6310, 6311, 6312, 6313, 6314, 6315, 6316, 6317, 6318, 6319, 6320,
    6321, 6322, 6323, 6324, 6325, 6326, 6327, 6328, 6329, 6330, 6331, 6332,
    6333, 6334, 6335, 6336, 6337, 6338, 6339, 6340, 6341, 6342, 6343, 6344,
    6345, 6346, 6347, 6348, 6349, 6350, 6351, 6352, 6353, 6401, 6402, 6403,
    6404, 6405, 7000, 7001, 7002, 7003, 7004, 7005, 7006, 7007, 7008, 7009,
    7010, 7011, 7012, 7013, 7014, 7015, 7016, 7017, 7018, 7019, 7020, 7021,
    7022, 7023, 7024, 7025, 7026, 7027, 7030, 7031, 7035, 7036, 7039, 7040,
    7041, 7042, 7050, 7060, 7061, 7062, 7063, 7064, 7070, 7100, 7101, 7110,
    7111, 7112, 7140, 7150, 7151, 7152, 7153, 7154, 7155, 7156, 7157, 7158,
    7159, 7160, 7161, 7162, 7163, 7165, 7166, 7167, 7168, 7169, 7170, 7171,
    7180, 7181, 7182, 7183, 7184, 7185, 7186, 7191, 7192, 7193, 7194, 7195,
    7196, 7197, 7198, 7199, 7201, 7202, 7203, 7205, 7210, 7215, 7220, 7221,
    7222, 7230, 7250, 7260, 7261, 7262, 7263, 7270, 7271, 7272, 7273, 7274,
    7275, 7276, 7277, 7300, 7301, 7302, 7303, 7304, 7305, 7306, 7307, 7308,
    7309, 7310, 7320, 7445, 7448, 7449, 7450, 7451, 7452, 7453, 7454, 7455,
    7456, 7457, 7458, 7459, 7460, 7461, 7462, 7464, 7465, 7466, 7467, 7468,
    7469, 7470, 7471, 7472, 7473, 7474, 7475, 7476, 7477, 7478, 7479, 7480,
    7481, 7482, 7483, 7484, 7486, 7490, 7500, 7501, 7550, 7551, 7552, 7553,
    7600, 7601, 7602, 7603, 7604, 7701, 7702, 7703, 7704, 7705, 7706, 7707,
    7710, 8101, 8102, 8103, 8104, 8109, 8110, 8111, 8112, 8113, 8114, 8115,
    8120, 8121, 8122, 8123, 8124, 8125, 8130, 8131, 8132, 8133, 8134, 8135,
    8136, 8201, 8202, 8203, 8300, 8301, 8302, 8303, 9000, 9231, 9232, 9233,
    9241, 9242,
    10000, 10001, 10002, 10003, 10004, 10005, 10006, 10007, 10008, 10009,
    10010, 10011, 10013, 10014, 10015, 10016, 10017, 10020, 10021, 10022,
    10023, 10024, 10025, 10026, 10027, 10028, 10029, 10030, 10031, 10033,
    10034, 10035, 10040, 10041, 10042, 10043, 10050, 10051, 10052, 10053,
    10054, 10060, 10061, 10062, 10063, 10064, 10065, 10066, 10067, 10068,
    10070, 10071, 10072, 10073,
    12100, 12101, 12102, 12103, 12104, 12105, 12106, 12107, 12108, 12109,
    12110, 12111, 12112, 12113, 12114, 12115, 12116, 12117, 12118, 12119,
    12120, 12200, 12201, 12202, 12203, 12204, 12205, 12206, 12207, 12208,
    12209, 12210, 12211, 12212, 12213, 12214, 12215, 12216, 12217, 12218,
    12219, 12220, 12221, 12222, 12223, 12224, 12225, 12226, 12227, 12228,
    12229, 12230, 12231, 12232, 12233, 12234, 12235, 12236, 12237, 12238,
    12239, 12240, 12241, 12242, 12243, 12244, 12245, 12246, 12247, 12248,
    12249, 12250, 12251, 12300, 12301, 12302, 12303, 12304, 12305, 12306,
    12307, 12308, 12309, 12310, 12311, 12312, 12313, 12314, 12315, 12316,
    12317, 12318, 12319, 12320,
]


def strip_tags(html):
    """Remove HTML tags, returning plain text."""
    return re.sub(r'<[^>]+>', '', html).strip()


def parse_cid_html(html, cid_num):
    """Parse CID page HTML using regex to extract metadata and codes."""
    result = {
        "cid": cid_num,
        "name": "",
        "extensible": True,
        "uid": "",
        "version": "",
        "codes": [],
        "includes": []
    }

    # Extract name from title: "Table CID NNN. Name" or heading "CID NNN Name"
    m = re.search(r'Table CID\s+\d+\.\s*([^<]+)', html)
    if m:
        result["name"] = strip_tags(m.group(1)).strip().rstrip('.')
    else:
        m = re.search(r'CID\s+\d+\s+([^<]+)', html)
        if m:
            result["name"] = strip_tags(m.group(1)).strip()

    # Extract extensibility
    if re.search(r'Non.?Extensible', html, re.IGNORECASE):
        result["extensible"] = False

    # Extract UID and version from definition list or paragraph
    m = re.search(r'UID[:\s]*</\w+>\s*<dd[^>]*>\s*<p[^>]*>[^<]*<[^>]*>([^<]+)', html)
    if not m:
        m = re.search(r'1\.2\.840\.10008\.6\.1\.\d+', html)
        if m:
            result["uid"] = m.group(0)
    else:
        result["uid"] = m.group(1).strip()

    m = re.search(r'Version[:\s]*</\w+>\s*<dd[^>]*>\s*<p[^>]*>[^<]*(?:<[^>]*>)*\s*(\d{8})', html)
    if m:
        result["version"] = m.group(1)

    # Find the data table (has frame="box")
    table_match = re.search(
        r'<table\s+frame="box"[^>]*>(.*?)</table>',
        html, re.DOTALL
    )
    if not table_match:
        return result

    table_html = table_match.group(1)

    # Extract tbody content
    tbody_match = re.search(r'<tbody>(.*?)</tbody>', table_html, re.DOTALL)
    if not tbody_match:
        return result

    tbody = tbody_match.group(1)

    # Process each row
    rows = re.findall(r'<tr[^>]*>(.*?)</tr>', tbody, re.DOTALL)
    for row_html in rows:
        cells = re.findall(r'<t[dh][^>]*>(.*?)</t[dh]>', row_html, re.DOTALL)
        if not cells:
            continue

        # Check for "Include" rows (single cell with colspan)
        first_text = strip_tags(cells[0])
        if 'include' in first_text.lower() or 'Include' in cells[0]:
            # Extract CID number from include reference
            include_match = re.search(r'CID\s+(\d+)', row_html)
            if include_match:
                result["includes"].append(int(include_match.group(1)))
            continue

        # Regular code row - need at least 3 cells
        if len(cells) >= 3:
            scheme = strip_tags(cells[0])
            value = strip_tags(cells[1])
            meaning = strip_tags(cells[2])

            # Skip header-like rows
            if scheme.lower() in ('coding scheme designator', 'coding scheme', ''):
                continue
            if not value:
                continue

            result["codes"].append({
                "scheme": scheme,
                "value": value,
                "meaning": meaning
            })

    return result


def fetch_cid(cid_num, retries=3):
    """Fetch and parse a single CID page."""
    url = f"{BASE_URL}/sect_CID_{cid_num}.html"
    headers = {"User-Agent": "DicomElixir/0.9.0 (CID scraper)"}

    for attempt in range(retries):
        try:
            req = Request(url, headers=headers)
            with urlopen(req, timeout=30) as resp:
                html = resp.read().decode("utf-8", errors="replace")

            return parse_cid_html(html, cid_num)
        except HTTPError as e:
            if e.code == 404:
                return None
            if attempt < retries - 1:
                time.sleep(2 ** attempt)
            else:
                print(f"  ERROR CID {cid_num}: HTTP {e.code}", file=sys.stderr)
                return None
        except (URLError, TimeoutError) as e:
            if attempt < retries - 1:
                time.sleep(2 ** attempt)
            else:
                print(f"  ERROR CID {cid_num}: {e}", file=sys.stderr)
                return None


def main():
    parser = argparse.ArgumentParser(description="Scrape DICOM CIDs from PS3.16")
    parser.add_argument("--output", default="priv/context_groups.json",
                        help="Output JSON file path")
    parser.add_argument("--workers", type=int, default=8,
                        help="Number of concurrent workers")
    parser.add_argument("--cids", type=str, default=None,
                        help="Comma-separated CID numbers to scrape (default: all)")
    args = parser.parse_args()

    cids = ALL_CIDS
    if args.cids:
        cids = [int(c.strip()) for c in args.cids.split(",")]

    print(f"Scraping {len(cids)} CIDs with {args.workers} workers...")
    results = []
    skipped = 0

    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        futures = {executor.submit(fetch_cid, cid): cid for cid in cids}
        for i, future in enumerate(as_completed(futures), 1):
            result = future.result()
            if result is None:
                skipped += 1
            else:
                results.append(result)
            if i % 100 == 0:
                print(f"  Progress: {i}/{len(cids)} ({len(results)} OK, {skipped} skipped)")

    results.sort(key=lambda x: x["cid"])

    total_codes = sum(len(r["codes"]) for r in results)
    extensible = sum(1 for r in results if r["extensible"])
    non_extensible = len(results) - extensible
    with_includes = sum(1 for r in results if r["includes"])
    empty = sum(1 for r in results if not r["codes"] and not r["includes"])

    print(f"\nResults:")
    print(f"  CIDs scraped:    {len(results)}")
    print(f"  Skipped (404):   {skipped}")
    print(f"  Total codes:     {total_codes}")
    print(f"  Extensible:      {extensible}")
    print(f"  Non-extensible:  {non_extensible}")
    print(f"  With includes:   {with_includes}")
    print(f"  Empty (no codes): {empty}")

    # Spot-check a few known CIDs
    by_cid = {r["cid"]: r for r in results}
    checks = [
        (244, "Laterality", False, 2),
        (29, "Acquisition Modality", True, 40),
        (6027, "BI-RADS Assessment Categories", True, 7),
    ]
    print(f"\nSpot checks:")
    for cid, expected_name, expected_ext, min_codes in checks:
        r = by_cid.get(cid)
        if r:
            ok = (expected_name in r["name"]) and (r["extensible"] == expected_ext) and (len(r["codes"]) >= min_codes)
            status = "OK" if ok else "MISMATCH"
            print(f"  CID {cid}: {status} (name={r['name']!r}, ext={r['extensible']}, codes={len(r['codes'])}, includes={r['includes']})")
        else:
            print(f"  CID {cid}: MISSING")

    with open(args.output, "w") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    print(f"\nWritten to {args.output} ({len(results)} entries)")


if __name__ == "__main__":
    main()
