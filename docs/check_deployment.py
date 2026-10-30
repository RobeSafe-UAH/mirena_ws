"""Identify the deployed revision and check every page advertised by MkDocs."""

import argparse
import json
import os
from pathlib import Path
import sys
import time
from html.parser import HTMLParser
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlsplit
from urllib.request import Request, urlopen
import xml.etree.ElementTree as ET


class CheckError(Exception):
    pass


class Generator(HTMLParser):
    mkdocs = False

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        if tag == "meta" and attrs.get("name", "").lower() == "generator":
            self.mkdocs |= attrs.get("content", "").lower().startswith("mkdocs")


def fetch(url, revision):
    request = Request(url + "?_revision=" + quote(revision, safe=""),
                      headers={"Cache-Control": "no-cache", "User-Agent": "Mirena-Pages-Check"})
    try:
        with urlopen(request, timeout=10) as response:
            if response.status != 200:
                raise CheckError(f"HTTP {response.status} en {urlsplit(url).path}")
            return response.read()
    except HTTPError as error:
        raise CheckError(f"HTTP {error.code} en {urlsplit(url).path}") from error
    except URLError as error:
        raise CheckError(f"No se pudo consultar {urlsplit(url).path}: {error.reason}") from error
    except TimeoutError as error:
        raise CheckError(f"Tiempo de espera agotado en {urlsplit(url).path}") from error


def check(base, revision):
    try:
        deployed = json.loads(fetch(base + "deployment.json", revision))
    except (ValueError, UnicodeError) as error:
        raise CheckError("deployment.json no contiene JSON válido") from error
    if not isinstance(deployed, dict) or deployed.get("revision") != revision:
        raise CheckError("La revisión publicada todavía no coincide con la esperada")
    try:
        sitemap = ET.fromstring(fetch(base + "sitemap.xml", revision))
    except ET.ParseError as error:
        raise CheckError("sitemap.xml no contiene XML válido") from error
    pages = {node.text.strip() for node in sitemap.iter()
             if node.tag.rsplit("}", 1)[-1] == "loc" and node.text}
    if base not in pages:
        raise CheckError("El sitemap no incluye la página de inicio")
    if any(not page.startswith(base) or urlsplit(page).query or urlsplit(page).fragment
           for page in pages):
        raise CheckError("El sitemap contiene una URL fuera de la base del sitio o con parámetros")
    for page in sorted(pages):
        parser = Generator()
        parser.feed(fetch(page, revision).decode("utf-8"))
        if not parser.mkdocs:
            raise CheckError(f"La página {urlsplit(page).path} no fue generada por MkDocs")
    return len(pages)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--write-version", type=Path, metavar="SITE_DIR")
    mode.add_argument("--url", help="URL base publicada, con barra final")
    parser.add_argument("--revision", help="SHA esperado para la comprobación")
    parser.add_argument("--attempts", type=int, default=12)
    parser.add_argument("--delay", type=float, default=5)
    args = parser.parse_args()
    if args.write_version is not None:
        revision = os.environ.get("GITHUB_SHA", "").strip()
        if not revision:
            parser.error("GITHUB_SHA debe contener la revisión que se publica")
        if not args.write_version.is_dir():
            parser.error("SITE_DIR debe ser el directorio del sitio ya construido")
        (args.write_version / "deployment.json").write_text(
            json.dumps({"revision": revision}) + "\n", encoding="utf-8")
        return 0
    base = urlsplit(args.url)
    if (base.scheme not in ("https", "http") or not base.netloc or base.username
            or base.password or base.query or base.fragment or not args.url.endswith("/")):
        parser.error("--url requiere una URL HTTP(S), sin credenciales ni parámetros y con barra final")
    if not args.revision or not args.revision.strip() or args.attempts < 1 or args.delay < 0:
        parser.error("Indicar --revision no vacío, --attempts >= 1 y --delay >= 0")
    for attempt in range(1, args.attempts + 1):
        try:
            count = check(args.url, args.revision)
            print(f"Publicación correcta: revisión {args.revision}; {count} páginas MkDocs comprobadas.")
            return 0
        except (CheckError, UnicodeError) as error:
            print(f"Intento {attempt}/{args.attempts}: {error}", file=sys.stderr)
            if attempt < args.attempts:
                time.sleep(args.delay)
    return 1


if __name__ == "__main__":
    sys.exit(main())
