fn main() {
    let mut lines: Vec<String> = Vec::new();
    let mut i: i64 = 0;
    while i < 60000 {
        if i % 2 == 0 {
            lines.push(format!("INFO id={} ok", i));
        } else {
            lines.push(format!("ERROR id={} fail", i));
        }
        i += 1;
    }
    let mut errors: i64 = 0;
    let mut k: usize = 0;
    while k < lines.len() {
        if lines[k].contains("ERROR") {
            errors += 1;
        }
        k += 1;
    }
    println!("{}", errors);
    println!("{}", lines.len());
    println!("{}", lines[1]);
    println!("{}", lines[59999].chars().count());
}
