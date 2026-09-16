fn main() {
    let o: Result<i64, String> = Ok(42);
    println!("{}", o.unwrap());
    let e: Result<i64, String> = Err("boom".into());
    println!("{}", e.unwrap_err());
}
