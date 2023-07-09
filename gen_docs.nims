cd thisDir()
exec "nimble doc --project --index " &
    "--git.url:https://git.sr.ht/~mjaa/xsdtonim " &
    "--git.commit:master " &
    "--outdir:htmldocs src/xsdtonim.nim"
