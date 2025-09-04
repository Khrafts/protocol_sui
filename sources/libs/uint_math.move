module protocol_sui::uint_math {
    /// Returns the minimum of two u256 values
    public fun min256(a: u256, b: u256): u256 {
        if (a < b) {
            a
        } else {
            b
        }
    }
    
    /// Returns the maximum of two u256 values
    public fun max256(a: u256, b: u256): u256 {
        if (a > b) {
            a
        } else {
            b
        }
    }
    
    /// Returns the minimum of two u128 values
    public fun min128(a: u128, b: u128): u128 {
        if (a < b) {
            a
        } else {
            b
        }
    }
    
    /// Returns the maximum of two u128 values
    public fun max128(a: u128, b: u128): u128 {
        if (a > b) {
            a
        } else {
            b
        }
    }
    
    /// Returns the minimum of two u64 values
    public fun min64(a: u64, b: u64): u64 {
        if (a < b) {
            a
        } else {
            b
        }
    }
    
    /// Returns the maximum of two u64 values
    public fun max64(a: u64, b: u64): u64 {
        if (a > b) {
            a
        } else {
            b
        }
    }
    
    /// Returns the minimum of two u32 values
    public fun min32(a: u32, b: u32): u32 {
        if (a < b) {
            a
        } else {
            b
        }
    }
    
    /// Returns the maximum of two u32 values
    public fun max32(a: u32, b: u32): u32 {
        if (a > b) {
            a
        } else {
            b
        }
    }
}