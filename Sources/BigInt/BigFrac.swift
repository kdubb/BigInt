//
//  BigFrac.swift
//  BigInt
//
//  Created by Leif Ibsen on 26/06/2022.
//

public struct BFraction: CustomStringConvertible, Comparable, Codable, Sendable, Equatable, Hashable {
    
    mutating func normalize() {
        let g = self.numerator.gcd(self.denominator)
        self.numerator = self.numerator.quotientExact(dividingBy: g)
        self.denominator = self.denominator.quotientExact(dividingBy: g)
        if self.denominator.isNegative {
            self.denominator.negate()
            self.numerator.negate()
        }
    }

    static func parseString(_ s: String) -> (mantissa: BInt, exponent: Int)? {
        enum State {
            case start
            case inInteger
            case inFraction
            case startExponent
            case inExponent
        }
        var state: State = .start
        var digits = 0
        var expDigits = 0
        var exp = ""
        var scale = 0
        var val = ""
        var negValue = false
        var negExponent = false
        for c in s {
            switch c {
            case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                if state == .start {
                    state = .inInteger
                    digits += 1
                    val.append(c)
                } else if state == .inInteger {
                    digits += 1
                    val.append(c)
                } else if state == .inFraction {
                    digits += 1
                    scale += 1
                    val.append(c)
                } else if state == .inExponent {
                    expDigits += 1
                    exp.append(c)
                } else if state == .startExponent {
                    state = .inExponent
                    expDigits += 1
                    exp.append(c)
                }
                break
            case ".":
                if state == .start || state == .inInteger {
                    state = .inFraction
                } else {
                    return nil
                }
                break
            case "E", "e":
                if state == .inInteger || state == .inFraction {
                    state = .startExponent
                } else {
                    return nil
                }
                break
            case "+":
                if state == .start {
                    state = .inInteger
                } else if state == .startExponent {
                    state = .inExponent
                } else {
                    return nil
                }
                break
            case "-":
                if state == .start {
                    state = .inInteger
                    negValue = true
                } else if state == .startExponent {
                    state = .inExponent
                    negExponent = true
                } else {
                    return nil
                }
                break
            default:
                return nil
            }
        }
        if digits == 0 {
            return nil
        }
        if (state == .startExponent || state == .inExponent) && expDigits == 0 {
            return nil
        }
        let w = negValue ? -BInt(val)! : BInt(val)!
        let E = Int(exp)
        if E == nil && expDigits > 0 {
            return nil
        }
        let e = expDigits == 0 ? 0 : (negExponent ? -E! : E!)
        return (w, e - scale)
    }

    static func displayString(_ significand: BInt, _ exponent: Int, _ exponential: Bool) -> String {
        var s = significand.abs.asString()
        let precision = s.count
        if exponential {
            
            // exponential notation
            
            let exp = precision + exponent - 1
            if s.count > 1 {
                s.insert(".", at: s.index(s.startIndex, offsetBy: 1))
            }
            s.append("E")
            if exp > 0 {
                s.append("+")
            }
            s.append(exp.description)
        } else {

            // plain notation
            
            if exponent > 0 {
                if !significand.isZero {
                    for _ in 0 ..< exponent {
                        s.append("0")
                    }
                }
            } else if exponent < 0 {
                if -exponent < precision {
                    s.insert(".", at: s.index(s.startIndex, offsetBy: precision + exponent))
                } else {
                    for _ in 0 ..< -(exponent + precision) {
                        s.insert("0", at: s.startIndex)
                    }
                    s.insert(".", at: s.startIndex)
                    s.insert("0", at: s.startIndex)
                }
            }
        }
        if significand.isNegative {
            s.insert("-", at: s.startIndex)
        }
        return s
    }


    // MARK: - Constants

    /// BFraction(0, 1)
    public static let ZERO = BFraction(BInt.ZERO, BInt.ONE)
    /// BFraction(1, 1)
    public static let ONE = BFraction(BInt.ONE, BInt.ONE)

    
    // MARK: Initializers

    /// Constructs a `BFraction` from numerator and denominator
    ///
    /// - Precondition: Denominator is not zero
    /// - Parameters:
    ///   - n: The numerator
    ///   - d: The denominator
    public init(_ n: BInt, _ d: BInt) {
        precondition(d.isNotZero)
        self.numerator = n
        self.denominator = d
        self.normalize()
    }

    /// Constructs a `BFraction` from numerator and denominator
    ///
    /// - Precondition: Denominator is not zero
    /// - Parameters:
    ///   - n: The numerator
    ///   - d: The denominator
    public init(_ n: BInt, _ d: Int) {
        self.init(n, BInt(d))
    }

    /// Constructs a `BFraction` from numerator and denominator
    ///
    /// - Precondition: Denominator is not zero
    /// - Parameters:
    ///   - n: The numerator
    ///   - d: The denominator
    public init(_ n: Int, _ d: BInt) {
        self.init(BInt(n), d)
    }

    /// Constructs a `BFraction` from numerator and denominator
    ///
    /// - Precondition: Denominator is not zero
    /// - Parameters:
    ///   - n: The numerator
    ///   - d: The denominator
    public init(_ n: Int, _ d: Int) {
        self.init(BInt(n), BInt(d))
    }

    /// Constructs a `BFraction` from a decimal value, `nil` if `d` is infinite or NaN
    ///
    /// - Parameters:
    ///   - d: The decimal value
    public init?(_ d: Double) {
        if d.isNaN || d.isInfinite {
            return nil
        }
        let bits = d.bitPattern
        let sign = bits >> 63 == 0 ? 1 : -1
        let exponent = Int(bits >> 52) & 0x7ff - 1075
        let significand = exponent == -1075 ? Int(bits & 0xfffffffffffff) << 1 : Int(bits & 0xfffffffffffff) | (1 << 52)
        if exponent < 0 {
            self.init(sign * BInt(significand), BInt.ONE << -exponent)
        } else {
            self.init(sign * BInt(significand) * (BInt.ONE << exponent), BInt.ONE)
        }
    }

    /// Constructs a `BFraction` from a String representation, `nil` if `x` does not represent a decimal number
    ///
    /// - Parameters:
    ///   - x: The String representation
    ///
    /// Examples:
    ///    * BFraction("3.1415") = 6283 / 2000
    ///    * BFraction("-12345E-3") = -2469 / 200
    ///    * BFraction("12345e3") = 12345000 / 1
    public init?(_ x: String) {
        guard let (m, e) = BFraction.parseString(x) else {
            return nil
        }
        if e < 0 {
            self.init(m, BInt.TEN ** -e)
        } else {
            self.init(m * (BInt.TEN ** e), BInt.ONE)
        }
    }
    
    /// Constructs a `BFraction` from a continued fraction - BInt version
    ///
    /// - Precondition: `x` contains at least one element, all elements except possibly the first are positive
    /// - Parameters:
    ///   - x: The continued fraction
    public init(_ x: [BInt]) {
        precondition(x.count > 0)
        var numerator = BInt.ZERO
        var denominator = BInt.ONE
        for i in (1 ..< x.count).reversed() {
            precondition(x[i].isPositive)
            numerator += x[i] * denominator
            (numerator, denominator) = (denominator, numerator)
        }
        numerator += x[0] * denominator
        self.init(numerator, denominator)
    }

    /// Constructs a `BFraction` from a continued fraction - Int version
    ///
    /// - Precondition: `x` contains at least one element, all elements except possibly the first are positive
    /// - Parameters:
    ///   - x: The continued fraction
    public init(_ x: [Int]) {
        var bx = [BInt](repeating: BInt.ZERO, count: x.count)
        for i in 0 ..< bx.count {
            bx[i] = BInt(x[i])
        }
        self.init(bx)
    }


    // MARK: Stored properties
    
    /// The numerator - a `BInt` value
    public internal(set) var numerator: BInt
    /// The denominator - a positive `BInt` value
    public internal(set) var denominator: BInt


    // MARK: Computed properties

    /// The absolute value of `self`
    public var abs: BFraction {
        return BFraction(self.numerator.abs, self.denominator)
    }

    /// String value of `self`
    public var description: String {
        return self.asString()
    }

    /// Is `true` if `self` is an integer, that is, the denominator is 1
    public var isInteger: Bool {
        return self.denominator.isOne
    }

    /// Is `true` if `self` < 0, `false` otherwise
    public var isNegative: Bool {
        return self.numerator.isNegative
    }

    /// Is `true` if `self` > 0, `false` otherwise
    public var isPositive: Bool {
        return self.numerator.isPositive
    }

    /// Is `true` if `self` = 0, `false` otherwise
    public var isZero: Bool {
        return self.numerator.isZero
    }

    /// Is 0 if `self` = 0, 1 if `self` > 0, and -1 if `self` < 0
    public var signum: Int {
        return self.numerator.signum
    }


    // MARK: Conversion functions to String, Decimal String, Double and Continued Fractions

    /// `self` as a String
    ///
    /// - Returns: `self` as a String
    public func asString() -> String {
        return self.numerator.asString() + " / " + self.denominator.asString()
    }

    /// `self` as a Decimal String with a specified precision, possibly using exponential notation
    ///
    /// - Precondition: `precision` > 0
    /// - Parameters:
    ///   - precision: The number of significant digits
    ///   - exponential: `true` to use exponential notation, `false` to use plain notation, default is `false`
    /// - Returns: `self` as a decimal String
    public func asDecimalString(precision: Int, exponential: Bool = false) -> String {
        precondition(precision > 0)
        if self.isZero {
            return BFraction.displayString(BInt.ZERO, -precision, exponential)
        }
        let P = BInt.TEN ** precision
        var exp = 0
        var q = self.numerator.abs
        while q.quotientAndRemainder(dividingBy: self.denominator).quotient < P {
            q *= BInt.TEN
            exp -= 1
        }
        while q.quotientAndRemainder(dividingBy: self.denominator).quotient >= P {
            q /= BInt.TEN
            exp += 1
        }
        let x = q.quotientAndRemainder(dividingBy: self.denominator).quotient
        return BFraction.displayString(self.isNegative ? -x : x, exp, exponential)
    }

    /// `self` as a Double
    ///
    /// - Returns: `self` as a Double or `Infinity` if `self` is not representable as a Double
    public func asDouble() -> Double {
        var (q, r) = self.numerator.quotientAndRemainder(dividingBy: self.denominator)
        var d = q.asDouble()
        if !d.isInfinite {
            var pow10 = 1.0
            for _ in 0 ..< 18 {
                r *= 10
                pow10 *= 10.0
                (q, r) = r.quotientAndRemainder(dividingBy: self.denominator)
                d += q.asDouble() / pow10
            }
        }
        return d
    }

    /// `self` as a Continued Fraction
    ///
    /// - Returns: `self` as a Continued Fraction
    public func asContinuedFraction() -> [BInt] {
        var numerator = self.numerator
        var denominator = self.denominator
        var (q, r) = numerator.quotientAndRemainder(dividingBy: denominator)
        var x = [q]
        if self.isNegative {
            x[0] -= 1
            numerator += (1 - x[0]) * denominator
            r += denominator
        }
        while r.isNotZero {
            (numerator, denominator) = (denominator, r)
            (q, r) = numerator.quotientAndRemainder(dividingBy: denominator)
            x.append(q)
        }
        return x
    }


    // MARK: Addition functions
    
    /// Prefix plus
    ///
    /// - Parameter x: BFraction value
    /// - Returns: `x`
    public prefix static func +(x: BFraction) -> BFraction {
        return x
    }
    
    /// Addition
    ///
    /// - Parameters:
    ///   - x: First addend
    ///   - y: Second addend
    /// - Returns: `x + y`
    public static func +(x: BFraction, y: BFraction) -> BFraction {
        if x.denominator == y.denominator {
            return BFraction(x.numerator + y.numerator, x.denominator)
        } else {
            return BFraction(x.numerator * y.denominator + y.numerator * x.denominator, x.denominator * y.denominator)
        }
    }

    /// Addition
    ///
    /// - Parameters:
    ///   - x: First addend
    ///   - y: Second addend
    /// - Returns: `x + y`
    public static func +(x: BFraction, y: BInt) -> BFraction {
        return BFraction(x.numerator + y * x.denominator, x.denominator)
    }

    /// Addition
    ///
    /// - Parameters:
    ///   - x: First addend
    ///   - y: Second addend
    /// - Returns: `x + y`
    public static func +(x: BInt, y: BFraction) -> BFraction {
        return BFraction(y.numerator + x * y.denominator, y.denominator)
    }

    /// Addition
    ///
    /// - Parameters:
    ///   - x: First addend
    ///   - y: Second addend
    /// - Returns: `x + y`
    public static func +(x: BFraction, y: Int) -> BFraction {
        return BFraction(x.numerator + y * x.denominator, x.denominator)
    }

    /// Addition
    ///
    /// - Parameters:
    ///   - x: First addend
    ///   - y: Second addend
    /// - Returns: `x + y`
    public static func +(x: Int, y: BFraction) -> BFraction {
        return BFraction(y.numerator + x * y.denominator, y.denominator)
    }

    /// x = x + y
    ///
    /// - Parameters:
    ///   - x: Left hand addend
    ///   - y: Right hand addend
    public static func +=(x: inout BFraction, y: BFraction) {
        x = x + y
    }
    
    /// x = x + y
    ///
    /// - Parameters:
    ///   - x: Left hand addend
    ///   - y: Right hand addend
    public static func +=(x: inout BFraction, y: BInt) {
        x = x + y
    }
    
    /// x = x + y
    ///
    /// - Parameters:
    ///   - x: Left hand addend
    ///   - y: Right hand addend
    public static func +=(x: inout BFraction, y: Int) {
        x = x + y
    }


    // MARK: Subtraction functions
    
    /// Negation
    ///
    /// - Parameter x: Operand
    /// - Returns: `-x`
    public prefix static func -(x: BFraction) -> BFraction {
        return BFraction(-x.numerator, x.denominator)
    }

    /// Negates `self`
    public mutating func negate() {
        self.numerator.negate()
    }

    /// Subtraction
    ///
    /// - Parameters:
    ///   - x: Minuend
    ///   - y: Subtrahend
    /// - Returns: `x - y`
    public static func -(x: BFraction, y: BFraction) -> BFraction {
        if x.denominator == y.denominator {
            return BFraction(x.numerator - y.numerator, x.denominator)
        } else {
            return BFraction(x.numerator * y.denominator - y.numerator * x.denominator, x.denominator * y.denominator)
        }
    }
    
    /// Subtraction
    ///
    /// - Parameters:
    ///   - x: Minuend
    ///   - y: Subtrahend
    /// - Returns: `x - y`
    public static func -(x: BFraction, y: BInt) -> BFraction {
        return BFraction(x.numerator - y * x.denominator, x.denominator)
    }

    /// Subtraction
    ///
    /// - Parameters:
    ///   - x: Minuend
    ///   - y: Subtrahend
    /// - Returns: `x - y`
    public static func -(x: BInt, y: BFraction) -> BFraction {
        return BFraction(y.numerator - x * y.denominator, y.denominator)
    }

    /// Subtraction
    ///
    /// - Parameters:
    ///   - x: Minuend
    ///   - y: Subtrahend
    /// - Returns: `x - y`
    public static func -(x: BFraction, y: Int) -> BFraction {
        return BFraction(x.numerator - y * x.denominator, x.denominator)
    }

    /// Subtraction
    ///
    /// - Parameters:
    ///   - x: Minuend
    ///   - y: Subtrahend
    /// - Returns: `x - y`
    public static func -(x: Int, y: BFraction) -> BFraction {
        return BFraction(y.numerator - x * y.denominator, y.denominator)
    }

    /// x = x - y
    ///
    /// - Parameters:
    ///   - x: Left hand minuend
    ///   - y: Right hand subtrahend
    public static func -=(x: inout BFraction, y: BFraction) {
        x = x - y
    }

    /// x = x - y
    ///
    /// - Parameters:
    ///   - x: Left hand minuend
    ///   - y: Right hand subtrahend
    public static func -=(x: inout BFraction, y: BInt) {
        x = x - y
    }

    /// x = x - y
    ///
    /// - Parameters:
    ///   - x: Left hand minuend
    ///   - y: Right hand subtrahend
    public static func -=(x: inout BFraction, y: Int) {
        x = x - y
    }


    // MARK: Multiplication functions
    
    /// Multiplication
    ///
    /// - Parameters:
    ///   - x: Multiplier
    ///   - y: Multiplicand
    /// - Returns: `x * y`
    public static func *(x: BFraction, y: BFraction) -> BFraction {
        return BFraction(x.numerator * y.numerator, x.denominator * y.denominator)
    }

    /// Multiplication
    ///
    /// - Parameters:
    ///   - x: Multiplier
    ///   - y: Multiplicand
    /// - Returns: `x * y`
    public static func *(x: BFraction, y: BInt) -> BFraction {
        return BFraction(x.numerator * y, x.denominator)
    }

    /// Multiplication
    ///
    /// - Parameters:
    ///   - x: Multiplier
    ///   - y: Multiplicand
    /// - Returns: `x * y`
    public static func *(x: BInt, y: BFraction) -> BFraction {
        return BFraction(x * y.numerator, y.denominator)
    }

    /// Multiplication
    ///
    /// - Parameters:
    ///   - x: Multiplier
    ///   - y: Multiplicand
    /// - Returns: `x * y`
    public static func *(x: BFraction, y: Int) -> BFraction {
        return BFraction(x.numerator * y, x.denominator)
    }

    /// Multiplication
    ///
    /// - Parameters:
    ///   - x: Multiplier
    ///   - y: Multiplicand
    /// - Returns: `x * y`
    public static func *(x: Int, y: BFraction) -> BFraction {
        return BFraction(x * y.numerator, y.denominator)
    }

    /// x = x * y
    ///
    /// - Parameters:
    ///   - x: Left hand multiplier
    ///   - y: Right hand multiplicand
    public static func *=(x: inout BFraction, y: BFraction) {
        x = x * y
    }

    /// x = x * y
    ///
    /// - Parameters:
    ///   - x: Left hand multiplier
    ///   - y: Right hand multiplicand
    public static func *=(x: inout BFraction, y: BInt) {
        x = x * y
    }

    /// x = x * y
    ///
    /// - Parameters:
    ///   - x: Left hand multiplier
    ///   - y: Right hand multiplicand
    public static func *=(x: inout BFraction, y: Int) {
        x = x * y
    }


    // MARK: Division functions

    /// Division
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Dividend
    ///   - y: Divisor
    /// - Returns: `x / y`
    public static func /(x: BFraction, y: BFraction) -> BFraction {
        return BFraction(x.numerator * y.denominator, x.denominator * y.numerator)
    }

    /// Division
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Dividend
    ///   - y: Divisor
    /// - Returns: `x / y`
    public static func /(x: BFraction, y: BInt) -> BFraction {
        return BFraction(x.numerator, x.denominator * y)
    }

    /// Division
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Dividend
    ///   - y: Divisor
    /// - Returns: `x / y`
    public static func /(x: BInt, y: BFraction) -> BFraction {
        return BFraction(x * y.denominator, y.numerator)
    }

    /// Division
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Dividend
    ///   - y: Divisor
    /// - Returns: `x / y`
    public static func /(x: BFraction, y: Int) -> BFraction {
        return BFraction(x.numerator, x.denominator * y)
    }

    /// Division
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Dividend
    ///   - y: Divisor
    /// - Returns: `x / y`
    public static func /(x: Int, y: BFraction) -> BFraction {
        return BFraction(x * y.denominator, y.numerator)
    }

    /// x = x / y
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Left hand dividend
    ///   - y: Right hand divisor
    public static func /=(x: inout BFraction, y: BFraction) {
        x = x / y
    }
    
    /// x = x / y
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Left hand dividend
    ///   - y: Right hand divisor
    public static func /=(x: inout BFraction, y: BInt) {
        x = x / y
    }
    
    /// x = x / y
    ///
    /// - Precondition: Divisor is not zero
    /// - Parameters:
    ///   - x: Left hand dividend
    ///   - y: Right hand divisor
    public static func /=(x: inout BFraction, y: Int) {
        x = x / y
    }

    /// Invert `self`
    ///
    /// - Precondition: `self` is not zero
    /// - Returns: `1 / self`
    public func invert() -> BFraction  {
        return BFraction(self.denominator, self.numerator)
    }


    // MARK: Modulus functions

    /// Modulus - BInt version
    ///
    /// - Precondition: Modulus is positive
    /// - Parameter m: Modulus
    /// - Returns: `self` `mod` m, a non-negative value or `nil` if the denominator and modulus are not coprime
    public func mod(_ m: BInt) -> BInt? {
        precondition(m.isPositive, "Modulus must be positive")
        guard self.denominator.gcd(m).isOne else {
            return nil
        }
        return (self.numerator * self.denominator.modInverse(m)).mod(m)
    }

    /// Modulus - Int version
    ///
    /// - Precondition: Modulus is positive
    /// - Parameter m: Modulus
    /// - Returns: `self` `mod` m, a non-negative value or `nil` if the denominator and modulus are not coprime
    public func mod(_ m: Int) -> Int? {
        precondition(m > 0, "Modulus must be positive")
        guard self.denominator.gcd(BInt(m)).isOne else {
            return nil
        }
        return (self.numerator * self.denominator.modInverse(m)).mod(m)
    }


    // MARK: Exponentiation functions

    /// Exponentiation
    ///
    /// - Parameters:
    ///   - a: Operand
    ///   - x: Exponent
    /// - Returns: `a^x`
    public static func **(a: BFraction, x: Int) -> BFraction {
        if x > 0 {
            return BFraction(a.numerator ** x, a.denominator ** x)
        } else if x < 0 {
            if x == Int.min {
                return BFraction(a.denominator * (a.denominator ** Int.max), a.numerator * (a.numerator ** Int.max))
            } else {
                return BFraction(a.denominator ** -x, a.numerator ** -x)
            }
        } else {
            return BFraction.ONE
        }
    }

    
    // MARK: Rounding functions
    
    /// Round to nearest
    ///
    /// - Returns: `self` rounded to the nearest integer
    public func round() -> BInt {
        let (q, r) = self.numerator.quotientAndRemainder(dividingBy: self.denominator)
        if r.isNegative {
            return -r * 2 >= self.denominator ? q - 1 : q
        } else {
            return r * 2 >= self.denominator ? q + 1 : q
        }
    }

    /// Round towards 0
    ///
    /// - Returns: `self` rounded to an integer towards 0
    public func truncate() -> BInt {
        return self.isPositive ? self.floor() : self.ceil()
    }

    /// Round towards +Infinity
    ///
    /// - Returns: `self` rounded to an integer towards +Infinity
    public func ceil() -> BInt {
        let (q, r) = self.numerator.quotientAndRemainder(dividingBy: self.denominator)
        return r.isPositive ? q + 1 : q
    }

    /// Round towards -Infinity
    ///
    /// - Returns: `self` rounded to an integer towards -Infinity
    public func floor() -> BInt {
        let (q, r) = self.numerator.quotientAndRemainder(dividingBy: self.denominator)
        return r.isNegative ? q - 1 : q
    }


    // MARK: Comparison functions
    
    /// Equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x = y, `false` otherwise
    public static func ==(x: BFraction, y: BFraction) -> Bool {
        return x.numerator == y.numerator && x.denominator == y.denominator
    }

    /// Equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x = y, `false` otherwise
    public static func ==(x: BFraction, y: BInt) -> Bool {
        return x.numerator == y && x.denominator.isOne
    }

    /// Equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x = y, `false` otherwise
    public static func ==(x: BInt, y: BFraction) -> Bool {
        return x == y.numerator && y.denominator.isOne
    }

    /// Equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x = y, `false` otherwise
    public static func ==(x: BFraction, y: Int) -> Bool {
        return x.numerator == y && x.denominator.isOne
    }

    /// Equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x = y, `false` otherwise
    public static func ==(x: Int, y: BFraction) -> Bool {
        return x == y.numerator && y.denominator.isOne
    }

    /// Not equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x != y, `false` otherwise
    public static func !=(x: BFraction, y: BFraction) -> Bool {
        return x.numerator != y.numerator || x.denominator != y.denominator
    }

    /// Not equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x != y, `false` otherwise
    public static func !=(x: BFraction, y: BInt) -> Bool {
        return x.numerator != y || !x.denominator.isOne
    }

    /// Not equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x != y, `false` otherwise
    public static func !=(x: BInt, y: BFraction) -> Bool {
        return y.numerator != x || !y.denominator.isOne
    }

    /// Not equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x != y, `false` otherwise
    public static func !=(x: BFraction, y: Int) -> Bool {
        return x.numerator != y || !x.denominator.isOne
    }

    /// Not equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x != y, `false` otherwise
    public static func !=(x: Int, y: BFraction) -> Bool {
        return y.numerator != x || !y.denominator.isOne
    }

    /// Less than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x < y, `false` otherwise
    public static func <(x: BFraction, y: BFraction) -> Bool {
        return x.numerator * y.denominator < y.numerator * x.denominator
    }

    /// Less than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x < y, `false` otherwise
    public static func <(x: BFraction, y: BInt) -> Bool {
        return x.numerator < y * x.denominator
    }

    /// Less than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x < y, `false` otherwise
    public static func <(x: BInt, y: BFraction) -> Bool {
        return x * y.denominator < y.numerator
    }

    /// Less than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x < y, `false` otherwise
    public static func <(x: BFraction, y: Int) -> Bool {
        return x.numerator < y * x.denominator
    }

    /// Less than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x < y, `false` otherwise
    public static func <(x: Int, y: BFraction) -> Bool {
        return x * y.denominator < y.numerator
    }

    /// Greater than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x > y, `false` otherwise
    public static func >(x: BFraction, y: BFraction) -> Bool {
        return x.numerator * y.denominator > y.numerator * x.denominator
    }

    /// Greater than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x > y, `false` otherwise
    public static func >(x: BFraction, y: BInt) -> Bool {
        return x.numerator > y * x.denominator
    }

    /// Greater than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x > y, `false` otherwise
    public static func >(x: BInt, y: BFraction) -> Bool {
        return x * y.denominator > y.numerator
    }

    /// Greater than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x > y, `false` otherwise
    public static func >(x: BFraction, y: Int) -> Bool {
        return x.numerator > y * x.denominator
    }

    /// Greater than
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x > y, `false` otherwise
    public static func >(x: Int, y: BFraction) -> Bool {
        return x * y.denominator > y.numerator
    }

    /// Less than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x <= y, `false` otherwise
    public static func <=(x: BFraction, y: BFraction) -> Bool {
        return !(x > y)
    }

    /// Less than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x <= y, `false` otherwise
    public static func <=(x: BFraction, y: BInt) -> Bool {
        return !(x > y)
    }

    /// Less than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x <= y, `false` otherwise
    public static func <=(x: BInt, y: BFraction) -> Bool {
        return !(x > y)
    }

    /// Less than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x <= y, `false` otherwise
    public static func <=(x: BFraction, y: Int) -> Bool {
        return !(x > y)
    }

    /// Less than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x <= y, `false` otherwise
    public static func <=(x: Int, y: BFraction) -> Bool {
        return !(x > y)
    }

    /// Greater than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x >= y, `false` otherwise
    public static func >=(x: BFraction, y: BFraction) -> Bool {
        return !(x < y)
    }

    /// Greater than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x >= y, `false` otherwise
    public static func >=(x: BFraction, y: BInt) -> Bool {
        return !(x < y)
    }

    /// Greater than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x >= y, `false` otherwise
    public static func >=(x: BInt, y: BFraction) -> Bool {
        return !(x < y)
    }

    /// Greater than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x >= y, `false` otherwise
    public static func >=(x: BFraction, y: Int) -> Bool {
        return !(x < y)
    }

    /// Greater than or equal
    ///
    /// - Parameters:
    ///   - x: First operand
    ///   - y: Second operand
    /// - Returns: `true` if x >= y, `false` otherwise
    public static func >=(x: Int, y: BFraction) -> Bool {
        return !(x < y)
    }


    // MARK: Miscellaneous functions

    /*
     * Compute via Tangent numbers
     */
    /// Bernoulli number
    ///
    /// - Precondition: `n >= 0`
    /// - Parameters:
    ///   - n: The Bernoulli index
    /// - Returns: The n'th Bernoulli number
    public static func bernoulli(_ n: Int) -> BFraction {
        precondition(n >= 0, "Negative Bernoulli index")
        if n == 0 {
            return BFraction.ONE
        } else if n == 1 {
            return BFraction(1, 2)
        } else if n & 1 == 1 {
            return BFraction.ZERO
        } else {
            let n1 = n >> 1
            var T = [BInt](repeating: BInt.ZERO, count: n1)
            T[0] = BInt.ONE
            for k in 1 ..< n1 {
                T[k] = k * T[k - 1]
            }
            for k in 1 ..< n1 {
                for j in k ..< n1 {
                    T[j] = (j - k) * T[j - 1] + (j - k + 2) * T[j]
                }
            }
            let numerator = T[n1 - 1] * n
            let N = BInt.ONE << n
            let denominator = N << n - N
            return n1 & 1 == 0 ? BFraction(-numerator, denominator) : BFraction(numerator, denominator)
        }
    }

    /// Bernoulli numbers
    ///
    /// - Precondition: `n > 0`
    /// - Parameters:
    ///   - n: The number of Bernoulli numbers to compute
    /// - Returns: The even numbered Bernoulli numbers B(0), B(2), B(4) ... B(2 * n - 2)
    public static func bernoulliSequence(_ n: Int) -> [BFraction] {
        precondition(n > 0, "Bernoulli count must be positive")
        if n == 1 {
            return [BFraction.ONE]
        } else {
            var x = [BFraction](repeating: BFraction.ONE, count: n)
            var T = [BInt](repeating: BInt.ONE, count: n)
            for k in 2 ..< n {
                T[k] = (k - 1) * T[k - 1]
            }
            for k in 2 ..< n {
                for j in k ..< n {
                    T[j] = (j - k) * T[j - 1] + (j - k + 2) * T[j]
                }
            }
            var p = BInt.ONE
            for k in 1 ..< n {
                p <<= 2
                let denominator = p * (p - 1)
                let numerator = (k + k) * T[k]
                x[k] = k & 1 == 0 ? BFraction(-numerator, denominator) : BFraction(numerator, denominator)
            }
            return x
        }
    }

    /// Harmonic number: 1 + 1 / 2 + ... + 1 / n
    ///
    /// - Precondition: `n > 0`
    /// - Parameters:
    ///   - n: The number of fractions to add
    /// - Returns: The n'th harmonic number
    public static func harmonic(_ n: Int) -> BFraction {
        precondition(n > 0)
        return _harmonic(1, n)
    }
    
    static func _harmonic(_ a: Int, _ b: Int) -> BFraction {
        if a == b {
            return BFraction(1, a)
        }
        let m = (a + b) >> 1
        return _harmonic(a, m) + _harmonic(m + 1, b)
    }
    
    /// Harmonic sequence: The first n harmonic numbers
    ///
    /// - Precondition: `n > 0`
    /// - Parameters:
    ///   - n: The number of harmonic numbers
    /// - Returns: The harmonic numbers: H1, H2 ... Hn
    public static func harmonicSequence(_ n: Int) -> [BFraction] {
        precondition(n > 0)
        var x = [BFraction](repeating: BFraction.ONE, count: n)
        for i in 1 ..< n {
            x[i] = x[i - 1] + BFraction(1, i + 1)
        }
        return x
    }
    
}
