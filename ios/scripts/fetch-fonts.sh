#!/usr/bin/env bash
# Downloads the two typefaces Recall uses (both SIL Open Font License 1.1)
# from the google/fonts repository into Recall/Resources/Fonts.
# Run once; the results are committed.
set -euo pipefail
cd "$(dirname "$0")/../Recall/Resources/Fonts"
base=https://raw.githubusercontent.com/google/fonts/main/ofl
curl -fsSL -o Newsreader-Variable.ttf        "$base/newsreader/Newsreader%5Bopsz,wght%5D.ttf"
curl -fsSL -o Newsreader-Italic-Variable.ttf "$base/newsreader/Newsreader-Italic%5Bopsz,wght%5D.ttf"
curl -fsSL -o IBMPlexMono-Regular.ttf        "$base/ibmplexmono/IBMPlexMono-Regular.ttf"
curl -fsSL -o IBMPlexMono-Medium.ttf         "$base/ibmplexmono/IBMPlexMono-Medium.ttf"
curl -fsSL -o OFL-Newsreader.txt             "$base/newsreader/OFL.txt"
curl -fsSL -o OFL-IBMPlexMono.txt            "$base/ibmplexmono/OFL.txt"
ls -l
