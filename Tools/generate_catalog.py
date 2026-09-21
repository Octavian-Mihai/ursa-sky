#!/usr/bin/env python3
"""Build Ursa Sky's bundled SQLite catalog from Yale BSC5 + authored IAU stick figures.

Primary star source: Yale Bright Star Catalogue, 5th Ed. (Hoffleit+, 1991) — public domain.
Names: IAU Catalog of Star Names (IAU-CSN), CC-BY.
Lines: original HR/HIP pairs for traditional IAU stick figures (not Stellarium).
Mythology: original short copy written for this app.

Usage:
    python3 Tools/generate_catalog.py
"""

from __future__ import annotations

import gzip
import io
import json
import os
import re
import sqlite3
import ssl
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TOOLS = Path(__file__).resolve().parent
CACHE = TOOLS / "cache"
DATA = TOOLS / "data"
RESOURCES = ROOT / "UrsaSky" / "Resources"

BSC5_URLS = [
    "https://cdsarc.cds.unistra.fr/ftp/cats/V/50/catalog.gz",
    "http://tdc-www.harvard.edu/catalogs/ybsc5.gz",
]
IAU_URLS = [
    "https://www.pas.rochester.edu/~emamajek/WGSN/IAU-CSN.txt",
]
TLE_URLS = [
    "https://celestrak.org/NORAD/elements/gp.php?CATNR=25544&FORMAT=tle",
    "https://celestrak.org/NORAD/elements/gp.php?GROUP=stations&FORMAT=tle",
]

BAYER = {
    "alp": "Alp", "alf": "Alp", "bet": "Bet", "gam": "Gam", "del": "Del",
    "eps": "Eps", "zet": "Zet", "eta": "Eta", "the": "The", "tet": "The",
    "iot": "Iot", "kap": "Kap", "lam": "Lam", "mu": "Mu", "nu": "Nu",
    "xi": "Xi", "omi": "Omi", "pi": "Pi", "rho": "Rho", "sig": "Sig",
    "tau": "Tau", "ups": "Ups", "phi": "Phi", "chi": "Chi", "psi": "Psi",
    "ome": "Ome",
}

# Traditional IAU stick figures as Bayer letter pairs (resolved to HR/HIP).
# Not copied from Stellarium or any GPL catalog.
BAYER_LINES = {
    "And": [("Alp", "Del"), ("Del", "Bet"), ("Bet", "Gam"), ("Bet", "Mu"), ("Mu", "Nu")],
    "Ant": [("Alp", "Iot"), ("Iot", "The"), ("The", "Eps")],
    "Aps": [("Alp", "Gam"), ("Gam", "Bet"), ("Bet", "Del")],
    "Aql": [("Gam", "Alp"), ("Alp", "Bet"), ("Alp", "Zet"), ("Zet", "Del"), ("Zet", "Lam"), ("Alp", "The"), ("The", "Eta")],
    "Aqr": [("Eps", "Mu"), ("Mu", "Bet"), ("Bet", "Alp"), ("Alp", "The"), ("The", "Iot"), ("Iot", "Del"), ("Alp", "Gam"), ("Gam", "Zet"), ("Zet", "Eta"), ("Eta", "Iot")],
    "Ara": [("Alp", "Bet"), ("Bet", "Gam"), ("Gam", "Del"), ("Zet", "Eps"), ("Eps", "Alp"), ("Bet", "Zet")],
    "Ari": [("Alp", "Bet"), ("Bet", "Gam")],
    "Aur": [("Alp", "Bet"), ("Bet", "The"), ("The", "Iot"), ("Iot", "Eps"), ("Eps", "Alp"), ("Alp", "Del"), ("Del", "Bet")],
    "Boo": [("Alp", "Eps"), ("Eps", "Del"), ("Del", "Bet"), ("Bet", "Gam"), ("Gam", "Rho"), ("Rho", "Alp"), ("Del", "Zet"), ("Zet", "Eta"), ("Eta", "Tau")],
    "Cae": [("Alp", "Bet"), ("Bet", "Gam")],
    "Cam": [("Alp", "Bet"), ("Bet", "Gam")],
    "Cap": [("Alp", "Omi"), ("Omi", "Psi"), ("Psi", "Ome"), ("Ome", "Zet"), ("Zet", "Iot"), ("Iot", "The"), ("The", "Bet"), ("Bet", "Alp"), ("The", "Del"), ("Del", "Gam")],
    "Car": [("Alp", "Bet"), ("Bet", "Ups"), ("Ups", "Iot"), ("Iot", "The"), ("The", "Ome"), ("Ome", "Chi"), ("Chi", "Eps")],
    "Cas": [("Alp", "Bet"), ("Bet", "Gam"), ("Gam", "Del"), ("Del", "Eps")],
    "Cen": [("Alp", "Bet"), ("Bet", "Eps"), ("Eps", "Gam"), ("Gam", "Iot"), ("Iot", "The"), ("The", "Nu"), ("Nu", "Mu"), ("Mu", "Zet"), ("Zet", "Eps"), ("Gam", "Sig"), ("Sig", "Del"), ("Del", "Pi"), ("Pi", "Lam")],
    "Cep": [("Alp", "Bet"), ("Bet", "Gam"), ("Gam", "Iot"), ("Iot", "Alp"), ("Alp", "Mu"), ("Mu", "Eps"), ("Eps", "Zet"), ("Zet", "Iot")],
    "Cet": [("Alp", "Lam"), ("Lam", "Mu"), ("Mu", "Xi2"), ("Xi2", "Gam"), ("Gam", "Del"), ("Del", "Omi"), ("Omi", "Zet"), ("Zet", "The"), ("The", "Eta"), ("Eta", "Iot"), ("Iot", "Bet"), ("Bet", "Tau"), ("Tau", "Zet")],
    "Cha": [("Alp", "Gam"), ("Gam", "Bet"), ("Bet", "Del")],
    "Cir": [("Alp", "Bet"), ("Bet", "Gam")],
    "CMa": [("Alp", "Bet"), ("Alp", "Gam"), ("Gam", "Iot"), ("Iot", "The"), ("The", "Gam"), ("Alp", "Eps"), ("Eps", "Del"), ("Del", "Eta"), ("Eps", "Zet")],
    "CMi": [("Alp", "Bet")],
    "Cnc": [("Alp", "Del"), ("Del", "Gam"), ("Gam", "Iot"), ("Iot", "Bet"), ("Del", "The")],
    "Col": [("Alp", "Bet"), ("Bet", "Gam"), ("Gam", "Del"), ("Alp", "Eps"), ("Eps", "Eta")],
    "Com": [("Alp", "Bet"), ("Bet", "Gam")],
    "CrA": [("Alp", "Bet"), ("Bet", "Del"), ("Del", "Gam"), ("Gam", "Eps"), ("Eps", "Zet"), ("Gam", "Alp")],
    "CrB": [("Alp", "Bet"), ("Bet", "The"), ("The", "Pi"), ("Pi", "Gam"), ("Gam", "Del"), ("Del", "Eps"), ("Eps", "Iot"), ("Gam", "Alp")],
    "Crt": [("Alp", "Bet"), ("Bet", "Gam"), ("Gam", "Del"), ("Del", "Eps"), ("Eps", "The"), ("The", "Zet"), ("Zet", "Eta"), ("Eta", "Bet")],
    "Cru": [("Alp", "Gam"), ("Bet", "Del")],
    "Crv": [("Alp", "Eps"), ("Eps", "Gam"), ("Gam", "Del"), ("Del", "Bet"), ("Bet", "Gam")],
    "CVn": [("Alp", "Bet")],
    "Cyg": [("Alp", "Del"), ("Del", "Gam"), ("Alp", "Eps"), ("Eps", "Zet"), ("Alp", "Bet")],
    "Del": [("Alp", "Bet"), ("Bet", "Del"), ("Del", "Gam"), ("Gam", "Alp"), ("Alp", "Eps")],
    "Dor": [("Alp", "Bet"), ("Bet", "Gam"), ("Gam", "Del")],
    "Dra": [("Bet", "Gam"), ("Gam", "Xi"), ("Xi", "Nu"), ("Nu", "Bet"), ("Gam", "Phi"), ("Phi", "Zet"), ("Zet", "Eta"), ("Eta", "The"), ("The", "Iot"), ("Iot", "Alp"), ("Alp", "Kap"), ("Kap", "Lam")],
    "Equ": [("Alp", "Del"), ("Del", "Gam"), ("Gam", "Bet")],
    "Eri": [("Bet", "Ome"), ("Ome", "Mu"), ("Mu", "Nu"), ("Nu", "Omi1"), ("Omi1", "Gam"), ("Gam", "Pi"), ("Pi", "Del"), ("Del", "Eps"), ("Eps", "Zet"), ("Zet", "Rho"), ("Rho", "Eta"), ("Eta", "Tau3"), ("Tau3", "Tau4"), ("Tau4", "Tau5"), ("Tau5", "Tau6"), ("Tau6", "Tau8"), ("Tau8", "Tau9"), ("Tau9", "Ups1"), ("Ups1", "Ups2"), ("Ups2", "Ups4"), ("Ups4", "The"), ("The", "Iot"), ("Iot", "Kap"), ("Kap", "Phi"), ("Phi", "Chi"), ("Chi", "Alp")],
    "For": [("Alp", "Bet"), ("Bet", "Nu")],
    "Gem": [("Alp", "Tau"), ("Tau", "Eps"), ("Eps", "Mu"), ("Mu", "Eta"), ("Eta", "Xi"), ("Xi", "Lam"), ("Lam", "Gam"), ("Gam", "Zet"), ("Zet", "Del"), ("Del", "Bet"), ("Bet", "Alp"), ("Iot", "Tau")],
    "Gru": [("Alp", "Bet"), ("Bet", "Del"), ("Alp", "Gam"), ("Gam", "Lam"), ("Alp", "Eps"), ("Eps", "Zet")],
    "Her": [("Alp", "Del"), ("Del", "Eps"), ("Eps", "Zet"), ("Zet", "Eta"), ("Eta", "Pi"), ("Pi", "Del"), ("Bet", "Zet"), ("Bet", "Gam"), ("Gam", "Del"), ("Eta", "The"), ("The", "Iot"), ("Iot", "Ome")],
    "Hor": [("Alp", "Del"), ("Del", "Bet")],
    "Hya": [("Zet", "Eps"), ("Eps", "Del"), ("Del", "Sig"), ("Sig", "Eta"), ("Eta", "Rho"), ("Rho", "Eps"), ("The", "Iot"), ("Iot", "Ups1"), ("Ups1", "Alp"), ("Alp", "Lam"), ("Lam", "Mu"), ("Mu", "Nu"), ("Nu", "Xi"), ("Xi", "Bet"), ("Bet", "Gam"), ("The", "Zet")],
    "Hyi": [("Alp", "Bet"), ("Bet", "Gam"), ("Gam", "Del"), ("Del", "Alp")],
    "Ind": [("Alp", "Bet"), ("Bet", "Del"), ("Alp", "The")],
    "Lac": [("Alp", "Bet"), ("Bet", "Gam"), ("Gam", "Zet"), ("Zet", "Eta"), ("Alp", "5")],
    "Leo": [("Eps", "Mu"), ("Mu", "Zet"), ("Zet", "Gam"), ("Gam", "Eta"), ("Eta", "Alp"), ("Alp", "The"), ("The", "Bet"), ("Bet", "Del"), ("Del", "The"), ("Del", "Iot"), ("Eta", "Gam")],
    "LMi": [("Bet", "46"), ("46", "31"), ("31", "21"), ("21", "10")],
    "Lep": [("Alp", "Bet"), ("Bet", "Eps"), ("Eps", "Mu"), ("Alp", "Gam"), ("Gam", "Del"), ("Del", "Bet"), ("Alp", "Zet"), ("Zet", "Eta")],
    "Lib": [("Alp", "Bet"), ("Bet", "Gam"), ("Gam", "Iot"), ("Alp", "Gam"), ("Bet", "Sig"), ("Sig", "Ups")],
    "Lup": [("Alp", "Bet"), ("Bet", "Gam"), ("Gam", "Del"), ("Del", "Phi"), ("Alp", "Zet"), ("Zet", "Eta"), ("Eta", "Gam")],
    "Lyn": [("Alp", "38"), ("38", "31"), ("31", "21"), ("21", "15"), ("15", "2")],
    "Lyr": [("Alp", "Eps"), ("Eps", "Zet"), ("Zet", "Bet"), ("Bet", "Del"), ("Del", "Gam"), ("Gam", "Zet")],
    "Men": [("Alp", "Gam"), ("Gam", "Eta"), ("Alp", "Bet")],
    "Mic": [("Alp", "Gam"), ("Gam", "Eps")],
    "Mon": [("Alp", "Del"), ("Del", "Zet"), ("Zet", "Bet"), ("Bet", "Gam"), ("Gam", "Del")],
    "Mus": [("Alp", "Bet"), ("Bet", "Del"), ("Del", "Gam"), ("Gam", "Alp"), ("Alp", "Eps")],
    "Nor": [("Gam2", "Eps"), ("Eps", "Eta"), ("Eta", "Gam2")],
    "Oct": [("Sig", "Tau"), ("Tau", "Chi"), ("Nu", "Bet")],
    "Oph": [("Alp", "Kap"), ("Kap", "Bet"), ("Bet", "Eta"), ("Eta", "Zet"), ("Zet", "Del"), ("Del", "Eps"), ("Eps", "Alp"), ("Del", "Nu"), ("Nu", "The"), ("Kap", "Lam")],
    "Ori": [("Alp", "Gam"), ("Gam", "Lam"), ("Lam", "Alp"), ("Alp", "Del"), ("Gam", "Del"), ("Del", "Eps"), ("Eps", "Zet"), ("Zet", "Kap"), ("Kap", "Bet"), ("Del", "Bet"), ("Zet", "The"), ("The", "Iot")],
    "Pav": [("Alp", "Bet"), ("Bet", "Del"), ("Del", "Eps"), ("Eps", "Zet"), ("Zet", "Eta"), ("Eta", "Pi"), ("Alp", "Gam"), ("Gam", "Del")],
    "Peg": [("Alp", "Bet"), ("Bet", "Gam"), ("Alp", "Xi"), ("Xi", "Zet"), ("Zet", "The"), ("The", "Eps"), ("Bet", "Eta"), ("Eta", "Omi")],
    "Per": [("Alp", "Gam"), ("Gam", "Del"), ("Del", "Eps"), ("Eps", "Bet"), ("Bet", "Rho"), ("Rho", "Gam"), ("Alp", "Del"), ("Alp", "Iot"), ("Iot", "Kap")],
    "Phe": [("Alp", "Bet"), ("Bet", "Gam"), ("Gam", "Eps"), ("Eps", "Alp"), ("Alp", "Del")],
    "Pic": [("Alp", "Bet"), ("Bet", "Gam")],
    "PsA": [("Alp", "Del"), ("Del", "Gam"), ("Gam", "Bet"), ("Bet", "Eps"), ("Eps", "Alp"), ("Alp", "Iot"), ("Iot", "Mu"), ("Mu", "Bet")],
    "Psc": [("Ome", "Iot"), ("Iot", "The"), ("The", "Lam"), ("Lam", "Kap"), ("Kap", "Gam"), ("Gam", "Tau"), ("Ome", "Del"), ("Del", "Eps"), ("Eps", "Zet"), ("Zet", "Mu"), ("Mu", "Nu"), ("Nu", "Xi"), ("Xi", "Alp"), ("Alp", "Omi"), ("Omi", "Eta"), ("Eta", "Rho"), ("Rho", "Iot")],
    "Pup": [("Zet", "Pi"), ("Pi", "Rho"), ("Rho", "Xi"), ("Xi", "Zet"), ("Zet", "Sig"), ("Pi", "Nu")],
    "Pyx": [("Alp", "Bet"), ("Bet", "Gam")],
    "Ret": [("Alp", "Bet"), ("Bet", "Del"), ("Del", "Gam"), ("Gam", "Alp")],
    "Scl": [("Alp", "Bet"), ("Bet", "Gam"), ("Gam", "Del")],
    "Sco": [("Pi", "Del"), ("Del", "Bet"), ("Bet", "Alp"), ("Alp", "Sig"), ("Sig", "Tau"), ("Tau", "Eps"), ("Eps", "Mu1"), ("Mu1", "Zet2"), ("Zet2", "Eta"), ("Eta", "The"), ("The", "Iot1"), ("Iot1", "Kap"), ("Pi", "Rho")],
    "Sct": [("Alp", "Bet"), ("Bet", "Gam"), ("Gam", "Del"), ("Del", "Alp")],
    "Ser": [("Iot", "Kap"), ("Kap", "Bet"), ("Bet", "Gam"), ("Gam", "Del"), ("Del", "Alp"), ("Alp", "Eps"), ("Gam", "Eps"), ("Eta", "The"), ("The", "Xi"), ("Xi", "Nu")],
    "Sex": [("Alp", "Bet"), ("Bet", "Gam")],
    "Sge": [("Zet", "Gam"), ("Gam", "Del"), ("Del", "Alp"), ("Del", "Bet")],
    "Sgr": [("Lam", "Phi"), ("Phi", "Sig"), ("Sig", "Tau"), ("Tau", "Zet"), ("Zet", "Eps"), ("Eps", "Gam"), ("Gam", "Del"), ("Del", "Lam"), ("Lam", "Mu"), ("Mu", "Zet"), ("Sig", "Zet"), ("Phi", "Lam")],
    "Tau": [("Bet", "Eps"), ("Eps", "Del"), ("Del", "Gam"), ("Gam", "Lam"), ("Lam", "Alp"), ("Alp", "The"), ("The", "Gam"), ("Bet", "Tau"), ("Tau", "Iot"), ("Iot", "Kap")],
    "Tel": [("Alp", "Zet"), ("Zet", "Eps")],
    "TrA": [("Alp", "Bet"), ("Bet", "Gam"), ("Gam", "Alp")],
    "Tri": [("Alp", "Bet"), ("Bet", "Gam"), ("Gam", "Alp")],
    "Tuc": [("Alp", "Del"), ("Del", "Gam"), ("Gam", "Bet"), ("Bet", "Zet"), ("Alp", "Eps")],
    "UMa": [("Alp", "Bet"), ("Bet", "Gam"), ("Gam", "Del"), ("Del", "Alp"), ("Del", "Eps"), ("Eps", "Zet"), ("Zet", "Eta"), ("Iot", "Kap"), ("Kap", "Lam"), ("The", "Ups"), ("Omi", "Pi"), ("Pi", "Rho")],
    "UMi": [("Alp", "Del"), ("Del", "Eps"), ("Eps", "Zet"), ("Zet", "Bet"), ("Bet", "Gam"), ("Gam", "Eta"), ("Eta", "Zet")],
    "Vel": [("Gam2", "Del"), ("Del", "Kap"), ("Kap", "Phi"), ("Phi", "Mu"), ("Mu", "Gam2"), ("Del", "Lam")],
    "Vir": [("Alp", "The"), ("The", "Del"), ("Del", "Eps"), ("Eps", "Alp"), ("Del", "Gam"), ("Gam", "Eta"), ("Eta", "Bet"), ("Bet", "Nu"), ("Del", "Zet"), ("Zet", "Tau")],
    "Vol": [("Alp", "Bet"), ("Bet", "Eps"), ("Eps", "Del"), ("Del", "Gam"), ("Gam", "Alp")],
    "Vul": [("Alp", "13"), ("13", "1")],
}

# Peg square closes through Alpheratz (And α). Extra HR/HIP pairs after resolve.
CROSS_CONSTELLATION = [("Peg", "Gam", "And", "Alp")]

# Original mythology / observing notes (not Wikipedia paste).
CONSTELLATIONS = {
    "And": ("Andromeda", "Andromedae", "autumn",
            "A princess chained at the waterline as a sacrifice, later found by a travelling hero. Her figure still stretches from the Great Square toward Perseus.",
            "Trace the long chain of second-magnitude stars east of Pegasus on autumn evenings.",
            "Alpheratz belongs to Andromeda even though it finishes the Square of Pegasus."),
    "Ant": ("Antlia", "Antliae", "spring",
            "A faint southern air-pump named in the age of scientific instruments, not a mythic creature.",
            "Look under Hydra in a dark spring sky; binoculars help more than the unaided eye.",
            "Lacaille placed Antlia among his workshop of modern machines."),
    "Aps": ("Apus", "Apodis", "summer",
            "The Bird of Paradise, a far-southern figure invented for voyaging star charts.",
            "Never rises for mid-northern observers; from the south it sits near the pole of the south.",
            "Its name is Greek for ‘footless,’ an old European rumor about birds of paradise."),
    "Aql": ("Aquila", "Aquilae", "summer",
            "Zeus’s eagle, the bird that carried the thunderbolt and, in one tale, the youth Ganymede.",
            "Find Altair, the middle bright star of the Summer Triangle, then the two flankers Tarazed and Alshain.",
            "Altair spins so fast it is flattened at the poles."),
    "Aqr": ("Aquarius", "Aquarii", "autumn",
            "A water-bearer pouring a stream toward the Southern Fish. Some old skies called him Ganymede at work.",
            "A large, dim autumn constellation; start from Sadalmelik and follow the water jar.",
            "The ‘water’ region of the sky also holds Cetus, Pisces, and Capricornus."),
    "Ara": ("Ara", "Arae", "summer",
            "The altar of the gods, smoke rising in the far south after a victory over the Titans.",
            "From southern latitudes it sits below Scorpius’s tail in winter evenings.",
            "Greek sailors treated Ara as a sign of fair weather when it stood high."),
    "Ari": ("Aries", "Arietis", "autumn",
            "The ram whose golden fleece sent Jason sailing. Only a short crooked line of stars remains.",
            "Hamal and Sheratan make a bright pair below Andromeda in late autumn.",
            "The Sun used to enter Aries at the March equinox; precession has moved that point into Pisces."),
    "Aur": ("Auriga", "Aurigae", "winter",
            "A charioteer who also carries a goat and her kids on his arm — a mix of driver and herdsman.",
            "Capella is the bright yellow star of winter’s pentagon, north of Orion.",
            "The Kids (ε, ζ, η Aur) are a tight test for a steady winter night."),
    "Boo": ("Boötes", "Boötis", "spring",
            "A herdsman following the Great Bear around the pole, sometimes called the ploughman of the northern sky.",
            "Arcturus is the spring arc off the Dipper’s handle — ‘arc to Arcturus.’",
            "Boötes is one of the largest northern constellations, yet most of its stars are modest."),
    "Cae": ("Caelum", "Caeli", "winter",
            "The sculptor’s chisel, another of Lacaille’s workshop tools in the southern sky.",
            "A dim patch between Eridanus and Columba; binoculars show a few fourth-magnitude sparks.",
            "There is almost no mythology: it is an 18th-century invention."),
    "Cam": ("Camelopardalis", "Camelopardalis", "winter",
            "A giraffe stretching through a nearly empty polar field, named when telescopes first filled the gaps.",
            "Sweep between the Dipper and Cassiopeia; the figure is a test of a dark site.",
            "The name is literally ‘camel-leopard,’ the old word for giraffe."),
    "Cap": ("Capricornus", "Capricorni", "autumn",
            "A sea-goat — goat in front, fish behind — a strange hybrid of the watery autumn sky.",
            "A large triangle of modest stars south of Aquila; Deneb Algedi marks the tail.",
            "The tropic of Capricorn is named for the Sun’s old December standstill here."),
    "Car": ("Carina", "Carinae", "winter",
            "The keel of the great ship Argo, split from a giant constellation into Carina, Puppis, and Vela.",
            "Canopus is the second-brightest star in the night sky; from the south it dominates summer evenings.",
            "Eta Carinae’s nebula sits in this keel, a reminder the ship still has weather."),
    "Cas": ("Cassiopeia", "Cassiopeiae", "autumn",
            "The seated queen who boasted of her beauty and was set in a chair that wheels around the pole.",
            "The bright W (or M) is circumpolar for much of the north and points toward Andromeda.",
            "She sits opposite the Big Dipper, so when one is high the other is low."),
    "Cen": ("Centaurus", "Centauri", "spring",
            "A wise centaur — often Chiron — holding a spear toward Lupus, teacher of heroes.",
            "Alpha and Beta Centauri are a brilliant southern pointer pair aimed at the Southern Cross.",
            "Proxima Centauri, the nearest star to the Sun, is a faint companion of α Cen."),
    "Cep": ("Cepheus", "Cephei", "autumn",
            "The king of Ethiopia, husband of Cassiopeia, standing by her chair at the pole.",
            "A house-shaped figure north of Cassiopeia; δ Cephei is the prototype Cepheid variable.",
            "The ‘house’ roof points roughly toward Polaris."),
    "Cet": ("Cetus", "Ceti", "autumn",
            "The sea-monster sent against Andromeda, sprawling across a huge patch of autumn water.",
            "Mira (ο Ceti) can vanish to the unaided eye and return as a red beacon months later.",
            "Cetus is the fourth-largest constellation, but few of its stars are bright."),
    "Cha": ("Chamaeleon", "Chamaeleontis", "spring",
            "A small southern chameleon crouching near the south celestial pole.",
            "Visible only from southern latitudes, tucked under Carina.",
            "It was drawn for Dutch voyagers in the 1590s."),
    "Cir": ("Circinus", "Circini", "spring",
            "The drawing compass of the southern workshop, tiny beside Centaurus.",
            "Look just east of α and β Centauri for a tight trio of fourth-magnitude stars.",
            "One of the smallest constellations in the sky."),
    "CMa": ("Canis Major", "Canis Majoris", "winter",
            "Orion’s greater hunting dog, forever chasing a hare across the winter Milky Way.",
            "Sirius, the night’s brightest star, leads the dog; the hindquarters run through Adhara.",
            "Sirius was Egypt’s Nile-flood star; its heliacal rising marked the new year."),
    "CMi": ("Canis Minor", "Canis Minoris", "winter",
            "The lesser dog, little more than two stars: Procyon and Gomeisa.",
            "Procyon rises before Sirius and with Betelgeuse makes the Winter Triangle.",
            "The name means ‘before the dog’ — Procyon precedes Sirius."),
    "Cnc": ("Cancer", "Cancri", "winter",
            "The crab sent to pinch Heracles in the marsh; a dim zodiac sign with a famous cluster in its shell.",
            "Find the Beehive (Praesepe) as a foggy patch between Leo and Gemini.",
            "The tropic of Cancer remembers when the June Sun stood here."),
    "Col": ("Columba", "Columbae", "winter",
            "Noah’s dove, set below Lepus as a later Christian addition to the old ship’s neighborhood.",
            "A small group south of Orion’s hare; Phact is the brightest.",
            "Bartsch named it in the 17th century as Columba Noachi."),
    "Com": ("Coma Berenices", "Comae Berenices", "spring",
            "The cut hair of Queen Berenice, offered for her husband’s safe return and placed among the stars.",
            "A soft scatter of stars north of Virgo; a dark site shows the Coma Cluster of galaxies.",
            "It was once the tuft at the end of Leo’s tail."),
    "CrA": ("Corona Australis", "Coronae Australis", "summer",
            "A southern crown lying at the feet of Sagittarius, a wreath more than a royal circlet.",
            "A graceful arc of fourth-magnitude stars under the Teapot’s spout.",
            "Greek poets already knew a southern wreath here."),
    "CrB": ("Corona Borealis", "Coronae Borealis", "spring",
            "Ariadne’s wedding crown, flung skyward by Dionysus after the labyrinth.",
            "A bright semicircle between Boötes and Hercules; Alphecca is the jewel.",
            "The ‘necklace’ is one of the easiest spring patterns after the Dipper."),
    "Crt": ("Crater", "Crateris", "spring",
            "Apollo’s cup, set on the back of Hydra beside the crow that fetched it.",
            "A goblet of faint stars west of Corvus on spring nights.",
            "The cup, crow, and water-snake form a single old story-board."),
    "Cru": ("Crux", "Crucis", "spring",
            "The Southern Cross, a small but brilliant kite used as a pointer to the south celestial pole.",
            "Follow the long axis of the Cross about 4.5 lengths to the unstarred pole.",
            "It is the smallest of the 88 constellations."),
    "Crv": ("Corvus", "Corvi", "spring",
            "Apollo’s crow, sent for water and delayed by a fig tree; the god set bird, cup, and snake together.",
            "A compact spring trapezoid west of Spica.",
            "Gienah and Algorab make a handy pair for hopping to Virgo."),
    "CVn": ("Canes Venatici", "Canum Venaticorum", "spring",
            "The hunting dogs of Boötes, held on a leash as he follows the Bear.",
            "Cor Caroli is the only bright star; the rest is galaxy country.",
            "Hevelius named the dogs in the 17th century."),
    "Cyg": ("Cygnus", "Cygni", "summer",
            "A swan in flight down the summer Milky Way — Zeus in disguise, or the lamenting Phaethon’s friend.",
            "The Northern Cross: Deneb at the tail, Albireo at the beak, wings to the sides.",
            "Albireo is a gold-and-blue double even in a small telescope."),
    "Del": ("Delphinus", "Delphini", "summer",
            "The dolphin that saved a poet, or the messenger that won Amphitrite for Poseidon.",
            "A tiny diamond (Job’s Coffin) plus a tail star, east of Altair.",
            "It is one of the few small figures that still looks like its name."),
    "Dor": ("Dorado", "Doradus", "winter",
            "A goldfish or dolphinfish of the southern voyaging charts, now famous for holding the Large Magellanic Cloud.",
            "From the south, look for the LMC as a detached piece of Milky Way in Dorado.",
            "The name is Spanish for the mahi-mahi, not the freshwater goldfish."),
    "Dra": ("Draco", "Draconis", "summer",
            "The dragon coiled around the north pole, a guardian of golden apples or a Titan’s ally.",
            "Start at the four-star head between Hercules and the Dipper, then follow the long body past Thuban.",
            "Thuban was the pole star when the pyramids were new."),
    "Equ": ("Equuleus", "Equulei", "autumn",
            "A little horse’s head, perhaps the brother of Pegasus, squeezed into a tiny autumn patch.",
            "Hard to see; look just west of Delphinus for a few fourth-magnitude sparks.",
            "It is the second-smallest constellation."),
    "Eri": ("Eridanus", "Eridani", "winter",
            "A long celestial river, sometimes the Nile, sometimes the Po, running from Orion’s foot to Achernar.",
            "Follow the winding chain of third-magnitude stars that starts near Rigel and ends at the bright southern beacon.",
            "Achernar’s name means ‘end of the river.’"),
    "For": ("Fornax", "Fornacis", "autumn",
            "The chemical furnace of Lacaille, a dim southern workshop beside Eridanus.",
            "Galaxy hunters know Fornax better than constellation-hoppers; the stars themselves are faint.",
            "The Fornax Cluster of galaxies lies here."),
    "Gem": ("Gemini", "Geminorum", "winter",
            "The twin brothers Castor and Pollux — one mortal, one divine — standing side by side.",
            "Two bright heads above Orion’s club; the rectangle of the twins’ bodies hangs south of them.",
            "The Geminid meteors pour from a radiant near Castor in December."),
    "Gru": ("Grus", "Gruis", "autumn",
            "A crane striding across the southern autumn sky, one of Bayer’s exotic birds.",
            "Alnair is the bright star; a line of lesser lights forms the neck.",
            "From the north it only skims the southern horizon."),
    "Her": ("Hercules", "Herculis", "summer",
            "The kneeling hero, head toward the south, resting after his labors.",
            "The Keystone of four stars is the torso; globular cluster M13 sits on the western side.",
            "He is drawn upside-down in many old atlases, still kneeling."),
    "Hor": ("Horologium", "Horologii", "autumn",
            "A pendulum clock, another of Lacaille’s instruments along the river Eridanus.",
            "A faint southern chain; useful mainly as a label on a chart.",
            "It honors the precision clocks that made longitude possible."),
    "Hya": ("Hydra", "Hydrae", "spring",
            "The many-headed water-serpent Heracles fought, the longest constellation in the sky.",
            "The head is a small loop south of Cancer; Alphard, the lonely heart, sits far to the east.",
            "Hydra spans more than 100 degrees of right ascension."),
    "Hyi": ("Hydrus", "Hydri", "autumn",
            "A male water snake of the deep south, not to be confused with the great Hydra.",
            "A thin triangle near the south pole and the Magellanic Clouds.",
            "Keyser and de Houtman introduced it from 16th-century voyages."),
    "Ind": ("Indus", "Indi", "autumn",
            "A figure meant as an indigenous person of the East Indies or the Americas, drawn for Dutch charts.",
            "A dim southern autumn group west of Grus and Tucana.",
            "It has no bright classical mythology."),
    "Lac": ("Lacerta", "Lacertae", "autumn",
            "A lizard slipped by Hevelius into a gap between Cygnus and Andromeda.",
            "A zigzag of modest stars on the Milky Way’s edge; best in binoculars.",
            "The ‘little lizard’ is easy to miss against richer neighbors."),
    "LMi": ("Leo Minor", "Leonis Minoris", "spring",
            "A small lion cub crouched under the Great Bear, added by Hevelius to a neglected polar gap.",
            "A dim chain between Leo’s sickle and Ursa Major; Praecipua is the only standout.",
            "There is no alpha star; β LMi and 46 LMi carry the figure."),
    "Leo": ("Leo", "Leonis", "spring",
            "The Nemean lion, first labor of Heracles, still showing a sickle for a head and a bright heart.",
            "Regulus anchors the sickle; Denebola is the tail-tip pointing at Virgo.",
            "The Leonid meteors radiate from the sickle in mid-November."),
    "Lep": ("Lepus", "Leporis", "winter",
            "The hare crouched under Orion’s feet, always about to be taken by the hunting dogs.",
            "A small box of third-magnitude stars directly below Rigel.",
            "Arneb is the hare’s brightest star."),
    "Lib": ("Libra", "Librae", "spring",
            "The scales of justice, once the claws of Scorpius before the Romans made them a separate sign.",
            "Zubenelgenubi and Zubeneschamali still bear names that mean ‘southern and northern claw.’",
            "It is the only zodiac constellation that is an object, not a living creature."),
    "Lup": ("Lupus", "Lupi", "spring",
            "A wolf held by the centaur, a southern beast with no single agreed myth.",
            "A knot of third-magnitude stars between Scorpius and Centaurus.",
            "It was once just a ‘wild animal’ on Greek lists."),
    "Lyn": ("Lynx", "Lyncis", "winter",
            "A lynx so faint, Hevelius said, that you need lynx-eyed vision to see it.",
            "A long dim chain between Ursa Major and Auriga; a true dark-sky test.",
            "There is almost no star brighter than third magnitude."),
    "Lyr": ("Lyra", "Lyrae", "summer",
            "Orpheus’s lyre, set beside the swan; Vega is the handle’s brilliant jewel.",
            "A small parallelogram hangs off Vega in the Summer Triangle.",
            "The Ring Nebula (M57) sits between γ and β Lyrae."),
    "Men": ("Mensa", "Mensae", "winter",
            "Table Mountain, named by Lacaille for the cape landmark under which he observed.",
            "Holds part of the Large Magellanic Cloud; otherwise extremely faint.",
            "It is the constellation of the south polar table."),
    "Mic": ("Microscopium", "Microscopii", "autumn",
            "A microscope among Lacaille’s instruments, south of Capricornus.",
            "No bright stars; treat it as a chart label unless you are hunting galaxies.",
            "It was carved from old southern stars of Piscis Austrinus’s neighborhood."),
    "Mon": ("Monoceros", "Monocerotis", "winter",
            "A unicorn set in the winter Milky Way between the dogs and Orion, a later invention.",
            "Dim against rich star fields; binoculars beat the naked eye.",
            "The Rosette and Christmas Tree regions lie in this unicorn."),
    "Mus": ("Musca", "Muscae", "spring",
            "A fly buzzing under the Southern Cross, originally a bee on some early charts.",
            "A compact southern group just below Crux.",
            "Dark nebulae of the Coalsack spill into Musca."),
    "Nor": ("Norma", "Normae", "summer",
            "A carpenter’s square, small and dim in the southern Milky Way.",
            "Rich star fields compensate for the faint official figure.",
            "Lacaille’s level and square sit beside Ara and Lupus."),
    "Oct": ("Octans", "Octantis", "year-round",
            "The octant that holds the south celestial pole — a faint instrument with no pole star to match Polaris.",
            "σ Octantis is a dim stand-in for a pole star, about a degree from the pole.",
            "The whole polar court is much emptier than the north."),
    "Oph": ("Ophiuchus", "Ophiuchi", "summer",
            "The serpent-bearer, a healer with a snake in both hands, often identified with Asclepius.",
            "A large pentagon west of the Milky Way’s summer bulge, between Hercules and Scorpius.",
            "The Sun spends more than two weeks here, though it is not a traditional zodiac sign."),
    "Ori": ("Orion", "Orionis", "winter",
            "The hunter, belt of three, shoulders and knees of first-magnitude fire, facing Taurus.",
            "The belt points down to Sirius and up toward Aldebaran. The sword holds the Orion Nebula.",
            "Betelgeuse is a huge aging red star; Rigel is a young blue supergiant."),
    "Pav": ("Pavo", "Pavonis", "summer",
            "A peacock of the southern sky, another Dutch voyaging bird.",
            "Peacock (α Pav) is the lone bright star; a fan of fainter lights spreads south.",
            "It is circumpolar from much of the southern hemisphere."),
    "Peg": ("Pegasus", "Pegasi", "autumn",
            "The winged horse sprung from Medusa, whose Great Square is the autumn landmark.",
            "Use the Square as a jumping-off point: off one corner, Andromeda; off another, a neck toward Delphinus.",
            "Alpheratz, the fourth corner, is catalogued in Andromeda."),
    "Per": ("Perseus", "Persei", "autumn",
            "The hero who rescued Andromeda, still holding a Gorgon’s head that winks as Algol.",
            "A rich Milky Way segment between Cassiopeia and Taurus; the Double Cluster sits on the Cassiopeia border.",
            "Algol, the Demon Star, eclipses every 2.87 days."),
    "Phe": ("Phoenix", "Phoenicis", "autumn",
            "The immortal bird of the south, rising beside Achernar.",
            "Ankaha (α Phe) is the main star; the rest is a modest autumn loop.",
            "Named on the same voyaging charts as Grus and Tucana."),
    "Pic": ("Pictor", "Pictoris", "winter",
            "The painter’s easel, a faint southern tool beside Dorado and Carina.",
            "Look west of Canopus for a thin line of fourth-magnitude stars.",
            "Lacaille first called it Equuleus Pictoris, the painter’s horse."),
    "PsA": ("Piscis Austrinus", "Piscis Austrini", "autumn",
            "The Southern Fish drinking the stream of Aquarius. Fomalhaut is its lonely first-magnitude eye.",
            "Fomalhaut stands almost alone in the autumn south; the rest of the fish is faint.",
            "Fomalhaut was one of the four royal stars of ancient Persia."),
    "Psc": ("Pisces", "Piscium", "autumn",
            "Two fish tied by a cord, a dim zodiac pair under Pegasus.",
            "The Circlet west of the Square is the easier fish; the cord runs east toward Aries.",
            "The vernal equinox now lies in Pisces because of precession."),
    "Pup": ("Puppis", "Puppis", "winter",
            "The stern of Argo, still sailing the winter Milky Way after the great ship was divided.",
            "A rich southern field under Canis Major; Naos is the brightest.",
            "It has no alpha star — those letters stayed with Carina."),
    "Pyx": ("Pyxis", "Pyxidis", "winter",
            "The mariner’s compass box of the split Argo, a small dim group east of Puppis.",
            "Three modest stars in a line in the winter Milky Way.",
            "Lacaille’s compass replaced an older mast on some charts."),
    "Ret": ("Reticulum", "Reticuli", "winter",
            "The reticle of an eyepiece, a tiny southern rhombus near the Magellanic Clouds.",
            "A neat diamond of fourth-magnitude stars west of Hydrus.",
            "Lacaille used a rhomboidal reticle to chart the south."),
    "Scl": ("Sculptor", "Sculptoris", "autumn",
            "The sculptor’s studio, a faint polar stretch of the south galactic pole.",
            "Almost empty to the eye; the Sculptor Galaxy (NGC 253) is the prize.",
            "Lacaille’s original name was Apparatus Sculptoris."),
    "Sco": ("Scorpius", "Scorpii", "summer",
            "The scorpion that stung Orion, still rearing a bright heart (Antares) and a hooked tail.",
            "Follow the fishhook of first- and second-magnitude stars along the summer Milky Way.",
            "Shaula and Lesath are the sting; the whole figure is one of the few that looks like its animal."),
    "Sct": ("Scutum", "Scuti", "summer",
            "Sobieski’s Shield, a small Milky Way patch Hevelius named for a Polish king.",
            "Rich star clouds between Aquila and Sagittarius; the Scutum Star Cloud is obvious in binoculars.",
            "It is among the smallest constellations but sits in glorious Milky Way."),
    "Ser": ("Serpens", "Serpentis", "summer",
            "The serpent in Ophiuchus’s hands, the only constellation split in two: Caput (head) and Cauda (tail).",
            "The head is a Y of stars west of the Keystone; the tail lies in the Milky Way east of Ophiuchus.",
            "Unukalhai is the heart of the head."),
    "Sex": ("Sextans", "Sextantis", "spring",
            "A sextant Hevelius placed under Leo, commemorating an instrument lost in a fire.",
            "Extremely faint; a chart is required.",
            "The south galactic pole is not far from this quiet field."),
    "Sge": ("Sagitta", "Sagittae", "summer",
            "A little arrow in flight toward Aquila, perhaps the one that slew an eagle or a Cyclops.",
            "Four modest stars between Vulpecula and Aquila; binoculars show the shape at once.",
            "It is the third-smallest constellation."),
    "Sgr": ("Sagittarius", "Sagittarii", "summer",
            "A centaur archer aiming at the scorpion’s heart, standing on the glow of the galactic center.",
            "The Teapot asterism is the easy summer key; the Milky Way steam rises from the spout.",
            "Nunki and Kaus Australis frame the pot."),
    "Tau": ("Taurus", "Tauri", "winter",
            "The bull Zeus became, face marked by the Hyades V and shoulder by the Pleiades.",
            "Aldebaran is the red eye; the Pleiades are a tiny dipper north of the head.",
            "The Taurid fireballs of autumn radiate from this face."),
    "Tel": ("Telescopium", "Telescopii", "summer",
            "A telescope of Lacaille’s, dim beside Ara and Corona Australis.",
            "Little to see without a chart; a southern winter curiosity.",
            "It was originally a longer tube overlapping neighboring figures."),
    "TrA": ("Triangulum Australe", "Trianguli Australis", "spring",
            "A bright southern triangle, counterpart to the smaller northern one.",
            "Three third-magnitude stars near Circinus and Norma make an obvious tripod.",
            "It is much more conspicuous than Triangulum in the north."),
    "Tri": ("Triangulum", "Trianguli", "autumn",
            "A small northern triangle under Andromeda, known to the Greeks as Deltoton.",
            "Three stars of third and fourth magnitude; M33, the Triangulum Galaxy, is the reason to linger.",
            "It is a handy stepping-stone from the Great Square to Aries."),
    "Tuc": ("Tucana", "Tucanae", "autumn",
            "A toucan of the southern voyaging charts, now famous for the Small Magellanic Cloud and 47 Tucanae.",
            "α Tuc is the beak; the SMC looks like a detached fog east of it.",
            "47 Tucanae is one of the sky’s finest globular clusters."),
    "UMa": ("Ursa Major", "Ursae Majoris", "spring",
            "The great bear whose dipper of seven stars still turns around the pole; a hunted creature in many northern stories.",
            "Use the bowl’s pointer stars to find Polaris, and arc the handle to Arcturus.",
            "Mizar in the handle has a naked-eye companion, Alcor."),
    "UMi": ("Ursa Minor", "Ursae Minoris", "year-round",
            "The little bear whose tail-tip is Polaris, the present north star.",
            "The Little Dipper is fainter than the Big; Kochab and Pherkad are the Guardians of the Pole.",
            "Polaris sits about 1° from the true pole and is a Cepheid of very small amplitude."),
    "Vel": ("Vela", "Velorum", "winter",
            "The sails of Argo, full of bright southern stars and a false cross that fools navigators.",
            "The False Cross (with Carina) is larger and dimmer than Crux; do not steer by it.",
            "γ Velorum is a rare Wolf–Rayet star visible to the unaided eye."),
    "Vir": ("Virgo", "Virginis", "spring",
            "A harvest maiden, wheat-ear in hand, identified with Persephone or Iustitia.",
            "Spica is the bright blue-white star two jumps from Arcturus: ‘spike to Spica.’",
            "The Virgo Cluster of galaxies crowds north of the maiden’s hip."),
    "Vol": ("Volans", "Volantis", "winter",
            "A flying fish leaping beside Carina and Dorado on the southern charts.",
            "A small kite of third- and fourth-magnitude stars near Miaplacidus.",
            "It is circumpolar from Tasmania and New Zealand."),
    "Vul": ("Vulpecula", "Vulpeculae", "summer",
            "Hevelius’s little fox, originally a fox with a goose, lying in the summer Milky Way.",
            "No bright pattern; the Dumbbell Nebula (M27) is the showpiece.",
            "The Coathanger asterism (Brocchi’s Cluster) hangs here in binoculars."),
}


def fetch(urls: list[str], dest: Path) -> Path:
    dest.parent.mkdir(parents=True, exist_ok=True)
    if dest.exists() and dest.stat().st_size > 1000:
        return dest
    ctx = ssl.create_default_context()
    last_err = None
    for url in urls:
        try:
            print(f"Downloading {url}")
            req = urllib.request.Request(url, headers={"User-Agent": "UrsaSky-catalog/1.0"})
            with urllib.request.urlopen(req, context=ctx, timeout=60) as resp:
                dest.write_bytes(resp.read())
            if dest.stat().st_size > 100:
                return dest
        except Exception as exc:  # noqa: BLE001 — try next mirror
            last_err = exc
            print(f"  failed: {exc}")
    if dest.exists() and dest.stat().st_size > 100:
        return dest
    raise RuntimeError(f"Could not download {dest.name}: {last_err}")


def parse_bsc5(path: Path) -> list[dict]:
    raw = path.read_bytes()
    if path.suffix == ".gz" or raw[:2] == b"\x1f\x8b":
        text = gzip.decompress(raw).decode("latin-1")
    else:
        text = raw.decode("latin-1")
    stars = []
    for line in text.splitlines():
        if len(line) < 107:
            continue
        try:
            hr = int(line[0:4])
        except ValueError:
            continue
        name_field = line[4:14]
        flam_s = name_field[0:3].strip()
        bayer = name_field[3:6].strip()
        con = name_field[7:10].strip()
        flam = None
        if flam_s.isdigit():
            flam = int(flam_s)
        rah, ram, ras = line[75:77], line[77:79], line[79:83]
        sgn, ded, dem, des = line[83:84], line[84:86], line[86:88], line[88:90]
        try:
            ra = (int(rah) + int(ram) / 60.0 + float(ras) / 3600.0) * 15.0
            dec = int(ded) + int(dem) / 60.0 + float(des) / 3600.0
            if sgn == "-":
                dec = -dec
        except ValueError:
            continue
        try:
            mag = float(line[102:107])
        except ValueError:
            mag = 99.0
        spect = line[127:147].strip() if len(line) >= 147 else ""
        dist_ly = None
        if len(line) >= 166:
            px_s = line[161:166].strip()
            try:
                px = float(px_s)
                if px > 0.001:
                    dist_ly = round(3.26156 / px, 1)
            except ValueError:
                pass
        stars.append({
            "hr": hr,
            "flamsteed": flam,
            "bayer": bayer or None,
            "iau": con or None,
            "ra": ra,
            "dec": dec,
            "mag": mag,
            "spect": spect or None,
            "dist_ly": dist_ly,
        })
    return stars


def parse_iau_csn(path: Path) -> dict[int, dict]:
    by_hr: dict[int, dict] = {}
    text = path.read_text(encoding="utf-8", errors="replace")
    for line in text.splitlines():
        if not line or line[0] in "#$(" :
            continue
        m = re.search(r"\bHR\s+(\d+)\b", line)
        if not m:
            continue
        hr = int(m.group(1))
        name = line[0:18].strip()
        hip_m = re.search(r"\bV\s+(\d+)\s+(\d+)\s+(-?\d+\.\d+)\s+(-?\d+\.\d+)", line)
        hip = None
        ra = dec = mag = None
        if hip_m:
            hip = int(hip_m.group(1))
        else:
            # fainter / unusual band; try HIP column near the end
            nums = re.findall(r"\s(\d+|_)\s+(\d+|_)\s+(-?\d+\.\d+)\s+(-?\d+\.\d+)\s+\d{4}-", line)
            if nums:
                hip_s, _hd, ra_s, dec_s = nums[-1]
                hip = int(hip_s) if hip_s.isdigit() else None
                ra, dec = float(ra_s), float(dec_s)
        mag_m = re.search(r"\s(-?\d+\.\d+)\s+[VGBgr]\s+", line)
        if mag_m:
            mag = float(mag_m.group(1))
        con_m = re.search(r"\b([A-Z][A-Za-z]{2})\b", line[40:80] if len(line) > 80 else line)
        by_hr[hr] = {
            "name": name,
            "hip": hip,
            "ra": ra,
            "dec": dec,
            "mag": mag,
            "iau": con_m.group(1) if con_m else None,
        }
    return by_hr


def fallback_from_iau(iau: dict[int, dict]) -> list[dict]:
    """Complete named-star catalog (typically mag ≤ 6) if BSC5 is unavailable."""
    stars = []
    for hr, info in sorted(iau.items()):
        mag = info.get("mag")
        if mag is None or mag > 6.5:
            continue
        ra, dec = info.get("ra"), info.get("dec")
        if ra is None or dec is None:
            continue
        stars.append({
            "hr": hr,
            "flamsteed": None,
            "bayer": None,
            "iau": info.get("iau"),
            "ra": ra,
            "dec": dec,
            "mag": mag,
            "spect": None,
            "dist_ly": None,
            "hip": info.get("hip"),
            "common_name": info.get("name"),
        })
    return stars


def lookup_star(by_con_bayer: dict, by_con_flam: dict, by_hr: dict, iau: str, token: str):
    t = token.strip()
    if t.isdigit():
        star = by_con_flam.get((iau, int(t)))
        if star:
            return star
        star = by_hr.get(int(t))
        return star
    key = (iau, t)
    star = by_con_bayer.get(key)
    if star:
        return star
    # prefix match: Mu1, The, Xi2
    for (c, bayer), s in by_con_bayer.items():
        if c == iau and (bayer == t or bayer.startswith(t) or t.startswith(bayer)):
            return s
    return None


def describe(star: dict) -> str:
    name = star.get("common_name") or star.get("display")
    con = star.get("iau") or "the field"
    spect = star.get("spect") or "untyped"
    mag = star.get("mag")
    mag_s = f"magnitude {mag:.2f}" if mag is not None and mag < 90 else "uncertain brightness"
    if star.get("common_name"):
        return f"{name} is a {spect} star of {mag_s} in {con}."
    if star.get("bayer"):
        return f"{star['bayer']} {con} is a {spect} star of {mag_s}."
    return f"HR {star['hr']} is a {spect} star of {mag_s}."


def extract_iss_tle(raw: str) -> str:
    lines = [ln.rstrip() for ln in raw.replace("\r", "").split("\n") if ln.strip()]
    for i, ln in enumerate(lines):
        if "ISS" in ln.upper() and "ZARYA" in ln.upper() and i + 2 < len(lines):
            return "\n".join(lines[i:i + 3]) + "\n"
        if ln.startswith("1 25544U") and i >= 1:
            return "\n".join(lines[i - 1:i + 2]) + "\n"
    # already a 3-line TLE
    if len(lines) >= 3 and lines[1].startswith("1 "):
        return "\n".join(lines[:3]) + "\n"
    return FALLBACK_TLE


FALLBACK_TLE = """ISS (ZARYA)
1 25544U 98067A   26263.14255447  .00007470  00000+0  14267-3 0  9991
2 25544  51.6307 190.1401 0004820 160.6694 199.4478 15.49188396586472
"""


def copy_json(src: Path, dest: Path) -> None:
    dest.write_bytes(src.read_bytes())


def build() -> None:
    CACHE.mkdir(parents=True, exist_ok=True)
    RESOURCES.mkdir(parents=True, exist_ok=True)
    DATA.mkdir(parents=True, exist_ok=True)

    bsc_path = CACHE / "catalog.gz"
    iau_path = CACHE / "IAU-CSN.txt"
    tle_path = CACHE / "iss.tle"

    iau_map: dict[int, dict] = {}
    try:
        fetch(IAU_URLS, iau_path)
        iau_map = parse_iau_csn(iau_path)
        print(f"IAU names: {len(iau_map)}")
    except Exception as exc:  # noqa: BLE001
        print(f"IAU-CSN unavailable ({exc}); continuing without common names.")

    stars: list[dict] = []
    source = "bsc5"
    try:
        fetch(BSC5_URLS, bsc_path)
        stars = parse_bsc5(bsc_path)
        print(f"BSC5 stars: {len(stars)}")
    except Exception as exc:  # noqa: BLE001
        print(f"BSC5 download/parse failed ({exc}); using named-star fallback.")
        source = "iau-named"
        if not iau_map:
            raise
        stars = fallback_from_iau(iau_map)

    by_hr = {}
    by_con_bayer = {}
    by_con_flam = {}
    for s in stars:
        info = iau_map.get(s["hr"], {})
        if info.get("name"):
            s["common_name"] = info["name"]
        if info.get("hip"):
            s["hip"] = info["hip"]
        s.setdefault("common_name", None)
        s.setdefault("hip", None)
        by_hr[s["hr"]] = s
        if s.get("iau") and s.get("bayer"):
            by_con_bayer[(s["iau"], s["bayer"])] = s
        if s.get("iau") and s.get("flamsteed"):
            by_con_flam[(s["iau"], s["flamsteed"])] = s

    line_rows = []
    line_json = []
    skipped = 0
    for iau, pairs in BAYER_LINES.items():
        seq = 0
        for a, b in pairs:
            sa = lookup_star(by_con_bayer, by_con_flam, by_hr, iau, a)
            sb = lookup_star(by_con_bayer, by_con_flam, by_hr, iau, b)
            if not sa or not sb:
                skipped += 1
                continue
            line_rows.append((iau, sa["hr"], sb["hr"], seq))
            line_json.append({
                "iau": iau,
                "a_hr": sa["hr"],
                "b_hr": sb["hr"],
                "a_hip": sa.get("hip"),
                "b_hip": sb.get("hip"),
                "seq": seq,
            })
            seq += 1
    for iau_a, bay_a, iau_b, bay_b in CROSS_CONSTELLATION:
        sa = lookup_star(by_con_bayer, by_con_flam, by_hr, iau_a, bay_a)
        sb = lookup_star(by_con_bayer, by_con_flam, by_hr, iau_b, bay_b)
        if sa and sb:
            line_rows.append((iau_a, sa["hr"], sb["hr"], 99))
            line_json.append({
                "iau": iau_a, "a_hr": sa["hr"], "b_hr": sb["hr"],
                "a_hip": sa.get("hip"), "b_hip": sb.get("hip"), "seq": 99,
            })

    (DATA / "constellation_lines.json").write_text(
        json.dumps({"license": "Original IAU stick figures as HR/HIP pairs. Not derived from Stellarium.",
                    "lines": line_json}, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Constellation line segments: {len(line_rows)} (skipped unmatched {skipped})")

    db_path = RESOURCES / "catalog.sqlite"
    if db_path.exists():
        db_path.unlink()
    con = sqlite3.connect(db_path)
    cur = con.cursor()
    cur.executescript("""
        CREATE TABLE stars (
            id INTEGER PRIMARY KEY,
            hr INTEGER UNIQUE,
            hip INTEGER,
            bayer TEXT,
            flamsteed INTEGER,
            common_name TEXT,
            iau TEXT,
            ra_j2000 REAL NOT NULL,
            dec_j2000 REAL NOT NULL,
            mag REAL,
            spect TEXT,
            dist_ly REAL,
            description TEXT
        );
        CREATE TABLE constellations (
            iau TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            genitive TEXT,
            mythology TEXT,
            brightest TEXT,
            season TEXT,
            fun_fact TEXT,
            tips TEXT,
            ra_cent REAL,
            dec_cent REAL
        );
        CREATE TABLE constellation_lines (
            iau TEXT NOT NULL,
            star_a INTEGER NOT NULL,
            star_b INTEGER NOT NULL,
            seq INTEGER NOT NULL
        );
        CREATE INDEX idx_stars_name ON stars(common_name);
        CREATE INDEX idx_stars_mag ON stars(mag);
        CREATE INDEX idx_stars_iau ON stars(iau);
        CREATE INDEX idx_lines_iau ON constellation_lines(iau);
    """)

    for s in stars:
        disp = s.get("common_name")
        if not disp:
            parts = []
            if s.get("flamsteed"):
                parts.append(str(s["flamsteed"]))
            if s.get("bayer"):
                parts.append(s["bayer"])
            if s.get("iau"):
                parts.append(s["iau"])
            disp = " ".join(parts) if parts else f"HR {s['hr']}"
        s["display"] = disp
        desc = describe(s)
        cur.execute(
            """INSERT INTO stars(hr, hip, bayer, flamsteed, common_name, iau,
               ra_j2000, dec_j2000, mag, spect, dist_ly, description)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?)""",
            (s["hr"], s.get("hip"), s.get("bayer"), s.get("flamsteed"),
             s.get("common_name"), s.get("iau"), s["ra"], s["dec"],
             s["mag"] if s["mag"] < 90 else None, s.get("spect"),
             s.get("dist_ly"), desc),
        )

    try:
        cur.execute("CREATE VIRTUAL TABLE star_fts USING fts5(common_name, bayer, iau, description, content='stars', content_rowid='id')")
        cur.execute("INSERT INTO star_fts(rowid, common_name, bayer, iau, description) SELECT id, common_name, bayer, iau, description FROM stars")
    except sqlite3.OperationalError as exc:
        print(f"FTS5 unavailable ({exc}); LIKE search will be used.")

    for iau, (name, genitive, season, myth, tips, fact) in CONSTELLATIONS.items():
        members = [s for s in stars if s.get("iau") == iau and s["mag"] < 90]
        brightest = ""
        if members:
            members.sort(key=lambda x: x["mag"])
            top = members[:3]
            bits = []
            for t in top:
                bits.append(t.get("common_name") or t["display"])
            brightest = ", ".join(bits)
        line_stars = [by_hr[a] for a, *_ in [(r[1],) for r in line_rows if r[0] == iau] if a in by_hr]
        line_stars += [by_hr[b] for b in (r[2] for r in line_rows if r[0] == iau) if b in by_hr]
        sample = line_stars or members
        ra_c = dec_c = None
        if sample:
            # circular mean in RA
            import math
            xs = sum(math.cos(math.radians(s["ra"])) for s in sample)
            ys = sum(math.sin(math.radians(s["ra"])) for s in sample)
            ra_c = (math.degrees(math.atan2(ys, xs)) + 360.0) % 360.0
            dec_c = sum(s["dec"] for s in sample) / len(sample)
        cur.execute(
            """INSERT INTO constellations(iau, name, genitive, mythology, brightest, season, fun_fact, tips, ra_cent, dec_cent)
               VALUES (?,?,?,?,?,?,?,?,?,?)""",
            (iau, name, genitive, myth, brightest, season, fact, tips, ra_c, dec_c),
        )

    cur.executemany(
        "INSERT INTO constellation_lines(iau, star_a, star_b, seq) VALUES (?,?,?,?)",
        line_rows,
    )
    con.commit()

    n_stars = cur.execute("SELECT COUNT(*) FROM stars").fetchone()[0]
    n_named = cur.execute("SELECT COUNT(*) FROM stars WHERE common_name IS NOT NULL AND common_name != ''").fetchone()[0]
    n_con = cur.execute("SELECT COUNT(*) FROM constellations").fetchone()[0]
    n_lines = cur.execute("SELECT COUNT(*) FROM constellation_lines").fetchone()[0]
    n_mag6 = cur.execute("SELECT COUNT(*) FROM stars WHERE mag <= 6.0").fetchone()[0]
    con.close()

    copy_json(DATA / "cities.json", RESOURCES / "cities.json")
    copy_json(DATA / "meteors.json", RESOURCES / "meteors.json")

    tle_text = FALLBACK_TLE
    try:
        fetch(TLE_URLS, tle_path)
        tle_text = extract_iss_tle(tle_path.read_text(encoding="ascii", errors="replace"))
    except Exception as exc:  # noqa: BLE001
        print(f"TLE fetch failed ({exc}); using bundled snapshot.")
        if tle_path.exists():
            tle_text = extract_iss_tle(tle_path.read_text(encoding="ascii", errors="replace"))
    (RESOURCES / "iss.tle").write_text(tle_text, encoding="ascii")

    stats = {
        "source": source,
        "stars": n_stars,
        "named": n_named,
        "mag_le_6": n_mag6,
        "constellations": n_con,
        "line_segments": n_lines,
        "cities": len(json.loads((DATA / "cities.json").read_text())["cities"]),
        "showers": len(json.loads((DATA / "meteors.json").read_text())["showers"]),
    }
    print(json.dumps(stats, indent=2))
    (CACHE / "catalog_stats.json").write_text(json.dumps(stats, indent=2) + "\n")


if __name__ == "__main__":
    try:
        build()
    except Exception as exc:
        print("ERROR:", exc, file=sys.stderr)
        sys.exit(1)
