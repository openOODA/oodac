fn main() {
    let mut row = String::new();
    let mut i: i64 = 0;
    while i < 6000 {
        row = row + "f" + &i.to_string() + ",";
        i += 1;
    }
    println!("{}", row.chars().count());
    println!("{}", row.len());
    println!("{}", if row.starts_with("f0,") { 1 } else { 0 });
    println!("{}", if row.contains("f5999,") { 1 } else { 0 });
    println!("{}", if row.ends_with(",") { 1 } else { 0 });
    println!("{}", "  pad  ".trim());
}
