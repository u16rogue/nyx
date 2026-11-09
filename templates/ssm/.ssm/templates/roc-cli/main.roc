app [main!] { pf: platform "https://github.com/roc-lang/basic-cli/releases/download/0.27.0/9yjxqdGTP4xSpSEmDazwTmRsehfRZzA19pwEKkR6fj1g.tar.zst" }

import pf.Stdout

main! = |_args| {
    Stdout.line!("Hello, World!")?
    Ok({})
}
