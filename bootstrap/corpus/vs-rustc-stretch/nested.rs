struct Employee {
    name: String,
    salary: i64,
}
struct Dept {
    lead: Employee,
    headcount: i64,
}
struct Company {
    eng: Dept,
    ops: Dept,
}

fn dept_cost(d: &Dept) -> i64 {
    d.lead.salary + d.headcount
}

fn payroll(c: &Company) -> i64 {
    dept_cost(&c.eng) + dept_cost(&c.ops)
}

fn lead_name(d: &Dept) -> &str {
    &d.lead.name
}

fn main() {
    let c = Company {
        eng: Dept {
            lead: Employee { name: "ada".into(), salary: 120 },
            headcount: 12,
        },
        ops: Dept {
            lead: Employee { name: "grace".into(), salary: 140 },
            headcount: 8,
        },
    };
    println!("{}", payroll(&c));
    println!("{}", lead_name(&c.eng));
    println!("{}", lead_name(&c.ops));
    let mut total: i64 = payroll(&c);
    let mut n: i64 = 0;
    while n < 100000 {
        let e = Employee { name: format!("c{}", n), salary: 100 + n };
        total += e.salary;
        n += 1;
    }
    println!("{}", total);
}
