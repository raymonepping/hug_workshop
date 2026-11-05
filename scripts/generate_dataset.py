#!/usr/bin/env python3
"""Generate deterministic synthetic acrostic data; this is a puzzle, not encryption."""
import argparse
import json
from pathlib import Path
import random
import re

WORDS='Architects Bridges Circuits Designs Engines Foundations Guardians Horizons Interfaces Junctions Keystones Ledgers Modules Nodes Orbits Patterns Queries Relays Systems Tokens Units Vaults Workflows Xylem Yields Zones'.split()

def generate(phrase,count=500,offset=101,seed=7):
    initials=re.sub('[^A-Z]','',phrase.upper())
    if not initials or count<len(initials) or count>100000 or offset<0:
        raise ValueError('Use a nonempty phrase, enough rows (maximum 100000), and nonnegative offset')
    rng=random.Random(seed)
    return [{'id':offset+i,'idx':offset+i,'title':WORDS[ord(initials[i] if i<len(initials) else rng.choice('ABCDEFGHIJKLMNOPQRSTUVWXYZ'))-65]+' '+rng.choice(['Teach Responsibility','Align With Intent','Build Trust Through Practice'])} for i in range(count)]

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--phrase',default='WE ARE THE GUARDIANS OF OUR OWN SYSTEMS')
    parser.add_argument('--count',type=int,default=500);parser.add_argument('--offset',type=int,default=101)
    parser.add_argument('--seed',type=int,default=7);parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--force',action='store_true');args=parser.parse_args()
    if args.out.exists() and not args.force:parser.error('Output exists; use --force to replace it')
    try:rows=generate(args.phrase,args.count,args.offset,args.seed)
    except ValueError as e:parser.error(str(e))
    args.out.write_text(''.join(json.dumps(row)+'\n' for row in rows))
    print('Wrote',len(rows),'synthetic records')
