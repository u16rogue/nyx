[package]
name = "{{subproject_name}}"
version = "{{subproject_version}}"
edition = "2024"

# run `./do lock` after changing these, package.nix reads Cargo.lock
[dependencies]

# the strictest sensible set. the rustc ones fail every build, the clippy ones fail `./do check`
# and show in the editor. opt out per item with `#[expect(<lint>, reason = "...")]`
[lints.rust]
# every warning is an error, of this crate only
warnings = "deny"
# functions are camel case here
non_snake_case = "allow"
# off by default
deprecated_safe = { level = "warn", priority = -1 }
future_incompatible = { level = "warn", priority = -1 }
keyword_idents = { level = "warn", priority = -1 }
let_underscore = { level = "warn", priority = -1 }
rust_2018_idioms = { level = "warn", priority = -1 }
unused = { level = "warn", priority = -1 }
ambiguous_negative_literals = "warn"
closure_returning_async_block = "warn"
macro_use_extern_crate = "warn"
meta_variable_misuse = "warn"
missing_copy_implementations = "warn"
missing_debug_implementations = "warn"
non_ascii_idents = "warn"
redundant_imports = "warn"
redundant_lifetimes = "warn"
single_use_lifetimes = "warn"
trivial_casts = "warn"
trivial_numeric_casts = "warn"
unit_bindings = "warn"
unnameable_types = "warn"
unreachable_pub = "warn"
unused_crate_dependencies = "warn"
unused_import_braces = "warn"
unused_lifetimes = "warn"
unused_macro_rules = "warn"
unused_qualifications = "warn"
variant_size_differences = "warn"

[lints.clippy]
all = { level = "warn", priority = -1 }
# the casts (sign, truncation, precision) are in here
pedantic = { level = "warn", priority = -1 }
# newer lints, the occasional false positive
nursery = { level = "warn", priority = -1 }
# picked from restriction, which isn't meant to be enabled as a whole
allow_attributes = "warn"
allow_attributes_without_reason = "warn"
as_underscore = "warn"
assertions_on_result_states = "warn"
clone_on_ref_ptr = "warn"
dbg_macro = "warn"
empty_drop = "warn"
empty_enum_variants_with_brackets = "warn"
empty_structs_with_brackets = "warn"
error_impl_error = "warn"
exit = "warn"
float_cmp_const = "warn"
fn_to_numeric_cast_any = "warn"
format_push_string = "warn"
get_unwrap = "warn"
if_then_some_else_none = "warn"
infinite_loop = "warn"
lossy_float_literal = "warn"
mem_forget = "warn"
mixed_read_write_in_expression = "warn"
mutex_atomic = "warn"
needless_raw_strings = "warn"
panic_in_result_fn = "warn"
pathbuf_init_then_push = "warn"
rc_buffer = "warn"
rc_mutex = "warn"
rest_pat_in_fully_bound_structs = "warn"
same_name_method = "warn"
semicolon_inside_block = "warn"
str_to_string = "warn"
string_lit_chars_any = "warn"
string_slice = "warn"
tests_outside_test_module = "warn"
todo = "warn"
try_err = "warn"
undocumented_unsafe_blocks = "warn"
unimplemented = "warn"
unnecessary_safety_comment = "warn"
unnecessary_safety_doc = "warn"
unnecessary_self_imports = "warn"
unneeded_field_pattern = "warn"
unused_result_ok = "warn"
unused_trait_names = "warn"
unwrap_in_result = "warn"
unwrap_used = "warn"
verbose_file_reads = "warn"
