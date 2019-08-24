import sys

from zipfile import ZipFile
from bs4 import BeautifulSoup


with ZipFile(sys.argv[1]) as zf:
    with zf.open('content.xml') as fh:

        soup = BeautifulSoup(fh, 'lxml-xml')

        style_names = []
        for style in soup.find_all('style:style'):
            for element in style.children:
                if element.get('style:text-underline-style') is not None:
                    style_names.append(style['style:name'])
        if not style_names:
            raise RuntimeError("no underline style found")

        for name in style_names:
            for span in soup.find_all('text:span', {'text:style-name': name}):
                print(span.text)

