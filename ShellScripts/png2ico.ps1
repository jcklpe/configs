@ECHO off

IF "%1"=="" (
    ECHO You must provide an svg file
    EXIT /b
)

IF NOT EXIST favicons MD favicons

SET "sizes=16 24 32 48 57 64 72 96 120 128 144 152 195 228 256 512"

FOR %%s IN (%sizes%) DO (
    inkscape -z -e favicons/favicon-%%s.png -w %%s -h %%s %1
)

convert favicons/favicon-16.png favicons/favicon-24.png favicons/favicon-32.png favicons/favicon-48.png favicons/favicon-64.png favicons/favicon.ico
