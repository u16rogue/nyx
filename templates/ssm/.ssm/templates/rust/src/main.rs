use std::error::Error;

fn main() -> Result<(), Box<dyn Error>> {
    let args: Vec<String> = std::env::args().skip(1).collect();
    if args.is_empty() {
        return Err("missing arguments".into());
    }

    #[cfg(debug_assertions)]
    for arg in &args {
        eprintln!("debug: {arg}");
    }

    Ok(())
}
