fn main() {
    let mut xs: Vec<i64> = Vec::new();
    let mut i: i64 = 0;
    while i < 200000 {
        xs.push(i);
        i += 1;
    }
    let mut j: usize = 0;
    while j < xs.len() {
        xs[j] *= 2;
        j += 1;
    }
    let mut s: i64 = 0;
    let mut k: usize = 0;
    while k < xs.len() {
        s += xs[k];
        k += 1;
    }
    println!("{}", s);
    let mid = &xs[1000..2000];
    println!("{}", mid.len());
    println!("{}", mid[0]);
}
