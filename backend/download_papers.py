import argparse
import os
import re
from urllib.parse import quote_plus, unquote, urljoin

import requests
from bs4 import BeautifulSoup

BASE_URL = "http://172.16.100.176:8080"

def sanitize_name(name):
    # Remove/replace characters that are invalid in Windows filenames
    return re.sub(r'[\\/*?:"<>|]', '-', name).strip()

def main():
    parser = argparse.ArgumentParser(
        description="Download question papers and bitstreams from DSpace repository by subject/author code."
    )
    parser.add_argument(
        "subject",
        nargs="?",
        default="CS F372",
        help="Subject or Author code (e.g. 'CS F372', 'CS+F372', or 'MATH F111'). Defaults to 'CS F372'."
    )
    args = parser.parse_args()

    subject_raw = args.subject.strip()
    # Normalize subject code for URL and Directory
    subject_for_url = quote_plus(subject_raw.replace("+", " ").replace("_", " "))
    folder_name = sanitize_name(subject_raw.replace("+", "_").replace(" ", "_"))

    browse_url = f"{BASE_URL}/jspui/handle/123456789/1/browse?type=author&order=ASC&rpp=100&value={subject_for_url}"
    output_dir = os.path.join(r"D:\PYQs", folder_name)

    os.makedirs(output_dir, exist_ok=True)
    session = requests.Session()
    session.headers.update({
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    })

    print(f"Subject Code: '{subject_raw}'")
    print(f"Output Directory: '{output_dir}'")
    print(f"Fetching browse page: {browse_url}")
    response = session.get(browse_url)
    response.raise_for_status()

    soup = BeautifulSoup(response.text, 'html.parser')

    # Find item links on the browse table
    item_links = []
    for a in soup.find_all('a', href=True):
        href = a['href']
        # DSpace item handle URLs match pattern like /jspui/handle/123456789/<id>
        if re.search(r'/handle/123456789/\d+$', href):
            full_url = urljoin(BASE_URL, href)
            if full_url not in item_links:
                item_links.append(full_url)

    print(f"Found {len(item_links)} item pages to process.")

    total_downloaded = 0

    for idx, item_url in enumerate(item_links, 1):
        print(f"\n[{idx}/{len(item_links)}] Visiting item page: {item_url}")
        item_id = item_url.split('/')[-1]
        
        try:
            item_res = session.get(item_url)
            item_res.raise_for_status()
            item_soup = BeautifulSoup(item_res.text, 'html.parser')

            # Extract year (issue date) from page
            issue_date = "UnknownYear"
            for row in item_soup.find_all('tr'):
                text = row.get_text()
                if "Issue Date:" in text:
                    tds = row.find_all('td')
                    if len(tds) >= 2:
                        issue_date = tds[1].get_text(strip=True)

            year_str = sanitize_name(issue_date)

            # Find all bitstream download links
            bitstream_links = []
            for a in item_soup.find_all('a', href=True):
                href = a['href']
                if '/bitstream/' in href:
                    full_bitstream_url = urljoin(BASE_URL, href)
                    if full_bitstream_url not in bitstream_links:
                        bitstream_links.append(full_bitstream_url)

            print(f"  Found {len(bitstream_links)} file(s) for item {item_id} (Year: {year_str})")

            for bitstream_url in bitstream_links:
                # Extract filename from URL and URL-decode %20, %2B, etc.
                raw_filename = bitstream_url.split('/')[-1].split('?')[0]
                original_filename = unquote(raw_filename)
                original_filename = sanitize_name(original_filename)

                if not original_filename:
                    original_filename = "attachment.pdf"

                # Format name as <year>_<filename>
                target_filename = f"{year_str}_{original_filename}"
                filepath = os.path.join(output_dir, target_filename)

                # Avoid overwriting if multiple papers share year & filename
                if os.path.exists(filepath):
                    target_filename = f"{year_str}_item{item_id}_{original_filename}"
                    filepath = os.path.join(output_dir, target_filename)

                print(f"  --> Downloading: {target_filename} from {bitstream_url}")

                file_res = session.get(bitstream_url, stream=True)
                file_res.raise_for_status()

                with open(filepath, 'wb') as f:
                    for chunk in file_res.iter_content(chunk_size=8192):
                        if chunk:
                            f.write(chunk)

                total_downloaded += 1
                print(f"      Saved to: {filepath}")

        except Exception as e:
            print(f"  Error processing item page {item_url}: {e}")

    print(f"\nFinished! Downloaded total of {total_downloaded} files to directory '{output_dir}'.")

if __name__ == "__main__":
    main()
