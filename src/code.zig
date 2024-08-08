const kls = @import("class_file.zig");
// Code_attribute {
// #     u2 attribute_name_index;
// #     u4 attribute_length;
// #     u2 max_stack;
// #     u2 max_locals;
// #     u4 code_length;
// #     u1 code[code_length];
// #     u2 exception_table_length;
// #     {   u2 start_pc;
// #         u2 end_pc;
// #         u2 handler_pc;
// #         u2 catch_type;
// #     } exception_table[exception_table_length];
// #     u2 attributes_count;
// #     attribute_info attributes[attributes_count];
// # }

pub const code_info = struct {
    // attribute_name_index: kls.t_u2,
    // attribute_length: kls.t_u4,
    max_stack: kls.t_u2,
    max_locals: kls.t_u2,
    code_length: kls.t_u4,
    code: []kls.t_u1,
    // exception_table_length: kls.t_u2,
    // exception_table: []exception_table,
    // attributes_count: kls.t_u2,
    // attributes: []kls.attribute_info,
};

pub const exception_table = struct {
    start_pc: kls.t_u2,
    end_pc: kls.t_u2,
    handler_pc: kls.t_u2,
    catch_type: kls.t_u2,
};
