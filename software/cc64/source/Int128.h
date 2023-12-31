#pragma once

class Int128
{
public:
	__int64 low;
	__int64 high;
public:
	Int128() {};
	Int128(int64_t val) {
		low = val;
		if (val < 0)
			high = 0xffffffffffffffffLL;
		else
			high = 0;
	};
	/*
	Int128 operator =(Int128& s) {
		this->high = s.high;
		this->low = s.low;
		return s;
	}
	*/
	Int128 operator =(Int128 s) {
		this->high = s.high;
		this->low = s.low;
		return s;
	}
	static Int128 *MakeInt128(int64_t val) {
		static Int128 p;

		p.low = val;
		if (val < 0)
			p.high = 0xffffffffffffffffLL;
		else
			p.high = 0;
		return (&p);
	};
	static Int128 *Zero() {
		static Int128 zr;
		zr.low = 0LL;
		zr.high = 0LL;
		return (&zr);
	};
	static Int128 *One() {
		static Int128 zr;
		zr.low = 1LL;
		zr.high = 0LL;
		return (&zr);
	};
	static Int128 MakeMask(int width) {
		Int128 a;
		Int128 one;

		a = *Int128::One();
		one = *Int128::One();
		a.Shl(&a, &a, width);
		a.Sub(&a, &a, &one);
		return (a);
	};

	static Int128 MakeMask(int offset, int width) {
		Int128 a;

		a = MakeMask(width);
		a.Shl(&a, &a, offset);
		return (a);
	};
	static void Assign(Int128 *a, Int128 *b) {
		a->low = b->low;
		a->high = b->high;
	};
	//fnASCarry = op? (~a&b)|(s&~a)|(s&b) : (a&b)|(a&~s)|(b&~s);
	// Compute carry bit from 64 bit addition.
	static bool AddCarry(__int64 s, __int64 a, __int64 b) {
		return (((a&b)|(a&~s)|(b&~s)) >> 63LL);
	};
	// Compute carry bit from 64 bit subtraction.
	static bool SubBorrow(__int64 s, __int64 a, __int64 b) {
		return (((~a&b)|(s&~a)|(s&b)) >> 63LL);
	};
	// Add two 128 bit numbers.
	static bool Add(Int128 *sum, Int128 *a, Int128 *b);
	// Subtract two 128 bit numbers.
	static bool Sub(Int128 *sum, Int128 *a, Int128 *b);
	static void BitAnd(Int128* dst, Int128* a, Int128* b) {
		dst->low = a->low & b->low;
		dst->high = a->high & b->high;
	};
	static void BitOr(Int128* dst, Int128* a, Int128* b) {
		dst->low = a->low | b->low;
		dst->high = a->high | b->high;
	};
	static void BitXor(Int128* dst, Int128* a, Int128* b) {
		dst->low = a->low ^ b->low;
		dst->high = a->high ^ b->high;
	};
	static void LogAnd(Int128* dst, Int128* a, Int128* b) {
		dst->low = a->low && b->low;
		dst->high = 0;
	};
	static void LogOr(Int128* dst, Int128* a, Int128* b) {
		dst->low = a->low || b->low;
		dst->high = 0;
	};
	// Shift left one bit.
	static bool Shl(Int128 *o, Int128 *a);
	static bool Shr(Int128 *o, Int128 *a);
	static bool Lsr(Int128* o, Int128* a);
	static bool Shl(Int128 *o, Int128 *a, int);
	static int64_t Shr(Int128 *o, Int128 *a, int);
	static int64_t Lsr(Int128* o, Int128* a, int);
	int64_t StickyCalc(int);
	static void Mul(Int128 *p, Int128 *a, Int128 *b);
	static void Div(Int128 *q, Int128 *r, Int128 *a, Int128 *b);
	static bool IsEqual(Int128 *a, Int128 *b);
	static bool IsLessThan(Int128 *a, Int128 *b);
	static bool IsUnsignedLessThan(Int128* a, Int128* b);
	static bool IsEQ(Int128* a, Int128* b) { return (IsEqual(a, b)); };
	static bool IsLT(Int128* a, Int128* b) { return (IsLessThan(a, b)); };
	static bool IsLE(Int128 *a, Int128 *b) { return (IsEqual(a, b) ||  IsLessThan(a, b)); };
	static bool IsGE(Int128 *a, Int128 *b) { return (IsEqual(a, b) || !IsLessThan(a, b)); };
	static bool IsGT(Int128* a, Int128* b) { return (!IsEqual(a, b) && !IsLessThan(a, b)); };
	static bool IsULT(Int128* a, Int128* b) { return (IsUnsignedLessThan(a, b)); };
	static bool IsULE(Int128* a, Int128* b) { return (IsEqual(a,b) || IsUnsignedLessThan(a, b)); };
	static bool IsUGE(Int128* a, Int128* b) { return (IsEqual(a, b) || !IsUnsignedLessThan(a, b)); };
	static bool IsUGT(Int128* a, Int128* b) { return (!IsEqual(a, b) && !IsUnsignedLessThan(a, b)); };
	static Int128 Convert(int64_t v) {
		Int128 p;

		p.low = v;
		if (v < 0)
			p.high = 0xffffffffffffffffLL;
		else
			p.high = 0;
		return (p);
	}
	static Int128 Convert(uint64_t v) {
		Int128 p;

		p.low = v;
		p.high = 0;
		return (p);
	}
	bool IsNBit(int bitno);
	void insert(int64_t i, int64_t offset, int64_t width);
	int64_t extract(int64_t offset, int64_t width);
	Int128 pwrof2();
};
