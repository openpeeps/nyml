task dev, "Compile Nyml":
    echo "\n✨ Compiling Nyml" & "\n"
    exec "nimble build --gc:arc -d:useMalloc"