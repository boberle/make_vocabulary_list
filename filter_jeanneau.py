"""
Remove examples from Jeanneau's dictionary (gloses starting with a hyphen).
"""

import sys
import re


for line in open(sys.argv[1]):
    if line.startswith("#") or not line.strip():
        print(line)
        continue
    entry, display, gloses = line.split("\t")
    pat = re.compile(r"(?:[^-]|- *\S+ -|- *\S+\.)")
    gloses = [
        x.strip() for x in gloses.split(r"\n")
        #if not x.lstrip().startswith('-')
        if pat.match(x.strip())
    ]
    gloses = [x for x in gloses if x]
    if gloses:
        print(entry + "\t" + display + "\t" + r'\n'.join(gloses))
    else:
        pass
        #print(line)
