module aptos_poker::deck {
    use std::vector;
    use aptos_poker::curve_baby_jubjub;

    struct Card has copy, drop, store { 
        x0: u256,
        y0: u256,
        x1: u256,
        y1: u256,
    }
    
    struct Deck has store { 
        cards: vector<Card>,
    }

    public fun new(): Deck {
        Deck { cards: vector::empty() } // Simple implementation
    }

    public fun draw(deck: &mut Deck): Card {
        vector::pop_back(&mut deck.cards) // Simple implementation
    }

    // Remove the card_to_u64 function

    public fun is_on_curve(x: u64, y: u64): bool {
        let p = curve_baby_jubjub::new_point((x as u256), (y as u256));
        curve_baby_jubjub::is_on_curve(p)
    }

    public fun point_add(x1: u64, y1: u64, x2: u64, y2: u64): (u64, u64) {
        let p1 = curve_baby_jubjub::new_point((x1 as u256), (y1 as u256));
        let p2 = curve_baby_jubjub::new_point((x2 as u256), (y2 as u256));
        let result = curve_baby_jubjub::point_add(p1, p2);
        ((curve_baby_jubjub::point_x(&result) as u64), (curve_baby_jubjub::point_y(&result) as u64))
    }

    public fun recover_y(x: u64, delta: u64, sign: bool): u64 {
        (curve_baby_jubjub::recover_y((x as u256), (delta as u256), sign) as u64)
    }

    public fun get_card_value(card: &Card): (u64, u64) {
        let result = curve_baby_jubjub::point_add(
            curve_baby_jubjub::new_point(card.x0, card.y0),
            curve_baby_jubjub::new_point(card.x1, card.y1)
        );
        ((curve_baby_jubjub::point_x(&result) as u64), (curve_baby_jubjub::point_y(&result) as u64))
    }

    // Other necessary functions
}