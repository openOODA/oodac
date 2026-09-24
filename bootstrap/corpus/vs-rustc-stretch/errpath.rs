fn validate_age(age: i64) -> Result<i64, String> {
    if age < 0 {
        return Err("negative age".into());
    }
    if age > 150 {
        return Err("implausible age".into());
    }
    Ok(age)
}

fn lookup_user(id: i64) -> Result<String, String> {
    if id < 0 {
        return Err("negative id".into());
    }
    if id > 1000 {
        return Err("unknown id".into());
    }
    Ok(format!("user-{}", id))
}

fn main() {
    let mut ok_count: i64 = 0;
    let mut err_count: i64 = 0;
    let mut a: i64 = 0;
    while a < 300000 {
        let v = match validate_age(a - 150000) {
            Ok(x) => x,
            Err(_) => -1,
        };
        if v >= 0 {
            ok_count += 1;
        } else {
            err_count += 1;
        }
        a += 1;
    }
    println!("{}", ok_count);
    println!("{}", err_count);
    let msg = match validate_age(200) {
        Ok(_) => "unexpected-ok".to_string(),
        Err(e) => e,
    };
    println!("{}", msg);
    let name = match lookup_user(42) {
        Ok(s) => s,
        Err(e) => e,
    };
    println!("{}", name);
    let m2 = match lookup_user(9999) {
        Ok(s) => s,
        Err(e) => e,
    };
    println!("{}", m2);
}
