import requests

bicleaner = 'https://github.com/bitextor/bicleaner-data/releases/latest/download'
#bicleaner_ai = 'https://github.com/bitextor/bicleaner-ai-data/releases/download/v1.0'
bicleaner_ai = 'https://huggingface.co/bitextor/bicleaner-ai'


def _exists(url):
    return requests.head(url, allow_redirects=True).status_code == 200


def find(src, trg):
    if _exists(f'{bicleaner_ai}-full-{src}-{trg}') or _exists(f'{bicleaner_ai}-full-{trg}-{src}'):
        return 'bicleaner-ai'

    if _exists(f'{bicleaner}/{src}-{trg}.tar.gz') or _exists(f'{bicleaner}/{trg}-{src}.tar.gz'):
        return 'bicleaner'

    return None
