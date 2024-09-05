module aptos_poker::curve_baby_jubjub {
    use std::error;

    // Constants
    const A: u256 = 168700;
    const D: u256 = 168696;
    const Q: u256 = 21888242871839275222246405745257275088548364400416034343698204186575808495617;

    // Error codes
    const EINVALID_DELTA: u64 = 1;
    const ENOT_ON_CURVE: u64 = 2;

    struct Point has copy, drop, store {
        x: u256,
        y: u256,
    }

    public fun new_point(x: u256, y: u256): Point {
        let p = Point { x, y };
        assert!(is_on_curve(p), error::invalid_argument(ENOT_ON_CURVE));
        p
    }

    public fun get_x(p: &Point): u256 { p.x }
    public fun get_y(p: &Point): u256 { p.y }

    public fun point_add(p1: Point, p2: Point): Point {
        if (p1.x == 0 && p1.y == 0) return p2;
        if (p2.x == 0 && p2.y == 0) return p1;
        let x1x2 = mulmod(p1.x, p2.x, Q);
        let y1y2 = mulmod(p1.y, p2.y, Q);
        let dx1x2y1y2 = mulmod(D, mulmod(x1x2, y1y2, Q), Q);
        let x3_num = addmod(mulmod(p1.x, p2.y, Q), mulmod(p1.y, p2.x, Q), Q);
        let y3_num = submod(y1y2, mulmod(A, x1x2, Q), Q);
        let x3 = mulmod(x3_num, inverse(addmod(1, dx1x2y1y2, Q)), Q);
        let y3 = mulmod(y3_num, inverse(submod(1, dx1x2y1y2, Q)), Q);
        Point { x: x3, y: y3 }
    }

    public fun point_mul(p: Point, d: u256): Point {
        let result = Point { x: 0, y: 1 };
        let mut_d = d;
        let mut_p = p;
        while (mut_d != 0) {
            if ((mut_d & 1) != 0) {
                result = point_add(result, mut_p);
            };
            mut_p = point_add(mut_p, mut_p);
            mut_d = mut_d >> 1;
        };
        result
    }

    public fun is_on_curve(p: Point): bool {
        let x_sq = mulmod(p.x, p.x, Q);
        let y_sq = mulmod(p.y, p.y, Q);
        let lhs = addmod(mulmod(A, x_sq, Q), y_sq, Q);
        let rhs = addmod(1, mulmod(mulmod(D, x_sq, Q), y_sq, Q), Q);
        submod(lhs, rhs, Q) == 0
    }

    public fun submod(a: u256, b: u256, m: u256): u256 {
        let a_nn = if (a <= b) a + m else a;
        addmod(a_nn - b, 0, m)
    }

    public fun inverse(a: u256): u256 {
        expmod(a, Q - 2, Q)
    }

    public fun expmod(b: u256, e: u256, m: u256): u256 {
        let result = 1;
        let current = b % m;
        let mut_e = e;
        while (mut_e > 0) {
            if (mut_e & 1 == 1) {
                result = mulmod(result, current, m);
            };
            current = mulmod(current, current, m);
            mut_e = mut_e >> 1;
        };
        result
    }

    public fun recover_y(x: u256, delta: u256, sign: bool): u256 {
        assert!(
            delta <= 10944121435919637611123202872628637544274182200208017171849102093287904247808,
            error::invalid_argument(EINVALID_DELTA)
        );
        assert!(is_on_curve(Point { x, y: delta }), error::invalid_argument(ENOT_ON_CURVE));
        if (sign) {
            delta
        } else {
            Q - delta
        }
    }

    public fun mulmod_public(a: u256, b: u256, m: u256): u256 {
        mulmod(a, b, m)
    }

    public fun mulmod(a: u256, b: u256, m: u256): u256 {
        let product = (a as u128) * (b as u128);
        let result = product % (m as u128);
        (result as u256)
    }

    public fun addmod(a: u256, b: u256, m: u256): u256 {
        let sum = (a as u128) + (b as u128);
        let result = sum % (m as u128);
        (result as u256)
    }

    public fun point_x(p: &Point): u256 { p.x }
    public fun point_y(p: &Point): u256 { p.y }

    public fun get_q(): u256 {
        Q
    }
}