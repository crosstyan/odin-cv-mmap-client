#include <cstdint>
#include <cstdio>

enum class StructBitfieldOrder {
  /// the most significant bit as the first appearing field in a struct
  MSB_AS_FIRST_FIELD,
  /// the least significant bit as the first appearing field in a struct
  LSB_AS_FIRST_FIELD,
  /// should not happen
  OTHER,
};

/**
 * @brief detect the bitfield order of the struct
 * @note Assuming the compiler does not reorder the bitfields
 */
StructBitfieldOrder struct_bitfield_order() {
  struct t {
    uint8_t zeros : 4;
    uint8_t ones : 4;
  };

  static_assert(sizeof(t) == 1);
  static bool has_value = false;
  static StructBitfieldOrder result = StructBitfieldOrder::OTHER;
  if (has_value) {
    return result;
  }
  constexpr auto test = t{.zeros = 0x0000, .ones = 0b1111};
  if (const uint8_t test_raw = *reinterpret_cast<const uint8_t *>(&test);
      test_raw == 0b00001111) {
    result = StructBitfieldOrder::MSB_AS_FIRST_FIELD;
  } else if (test_raw == 0b11110000) {
    result = StructBitfieldOrder::LSB_AS_FIRST_FIELD;
  } else {
    result = StructBitfieldOrder::OTHER;
  }
  has_value = true;
  return result;
}

const char *to_string(const StructBitfieldOrder order) {
  switch (order) {
  case StructBitfieldOrder::MSB_AS_FIRST_FIELD:
    return "MSB_AS_FIRST_FIELD";
  case StructBitfieldOrder::LSB_AS_FIRST_FIELD:
    return "LSB_AS_FIRST_FIELD";
  default:
    return "OTHER";
  }
}

// for the `x86_64-linux-gnu` platform, the output is `LSB_AS_FIRST_FIELD`
int main() { printf("%s\n", to_string(struct_bitfield_order())); }