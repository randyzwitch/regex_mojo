"""Compile once, then search borrowed UTF-8 without copying the input."""
from std.testing import assert_equal, assert_true
from regex_mojo import Matcher, cached_pattern


def main() raises:
    var pattern = cached_pattern("(?P<word>\\p{L}+)-(\\d+)")
    var matcher = Matcher(pattern)
    var text = String("café-42")
    var bytes = Span[UInt8, ImmutAnyOrigin](
        unsafe_ptr=text.unsafe_ptr().unsafe_origin_cast[ImmutAnyOrigin](),
        length=text.byte_length(),
    )
    assert_true(matcher.captures(bytes))
    assert_equal(matcher.slots[0], 0)
    assert_equal(matcher.slots[1], 8)
    assert_equal(pattern.group_index("word"), 1)
    print("Match byte offsets:", matcher.slots[0], matcher.slots[1])

    var output = List[UInt8]()
    _ = matcher.replace(bytes, pattern.template("${word}:$2"), -1, output)
    var replaced = String(StringSpan(unsafe_from_utf8=Span(output)))
    assert_equal(replaced, "café:42")
    print(replaced)
    # Keep the owner alive through every use of its borrowed bytes.
    _ = text
