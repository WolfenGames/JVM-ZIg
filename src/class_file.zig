const std = @import("std");

pub const t_u4 = u32;
pub const t_u2 = u16;
pub const t_u1 = u8;

pub const ClassFile = struct {
    magic: t_u4,
    minor_version: t_u2,
    major_version: t_u2,
    constant_pool_count: t_u2,
    constant_pool: []cp_info,
    access_flags: []const []const u8,
    this_class: t_u2,
    super_class: t_u2,
    interfaces: []interfaces,
    methods: []method_info,
    attributes: []attribute_info,
};

pub const interfaces = struct {};

pub const method_info = struct {
    access_flags: []const []const u8,
    name_index: t_u2,
    descriptor_index: t_u2,
    attributes_count: t_u2,
    attributes: []attribute_info,
};

pub const attribute_info = struct {
    attribute_name_index: t_u2,
    attribute_length: t_u4,
    info: []u8,
};

pub const cp_info = struct { tag: ConstantPoolTags, class_index: t_u2, name_and_type_index: t_u2, descriptor_index: t_u2, bytes: []t_u1, bytes_length: t_u2, string_index: t_u2, name_index: t_u2 };

pub const ConstantPoolTags = enum(t_u1) {
    CONSTANT_Class = 7,
    CONSTANT_Fieldref = 9,
    CONSTANT_Methodref = 10,
    CONSTANT_InterfaceMethodref = 11,
    CONSTANT_String = 8,
    CONSTANT_Integer = 3,
    CONSTANT_Float = 4,
    CONSTANT_Long = 5,
    CONSTANT_Double = 6,
    CONSTANT_NameAndType = 12,
    CONSTANT_Utf8 = 1,
    CONSTANT_MethodHandle = 15,
    CONSTANT_MethodType = 16,
    CONSTANT_InvokeDynamic = 18,

    pub fn fromInt(tag: u8) !ConstantPoolTags {
        return std.meta.intToEnum(ConstantPoolTags, tag);
    }
};

pub const ClassAccessFlags = struct {
    pub const ACC_PUBLIC = 0x0001;
    pub const ACC_FINAL = 0x0010;
    pub const ACC_SUPER = 0x0020;
    pub const ACC_INTERFACE = 0x0200;
    pub const ACC_ABSTRACT = 0x0400;
    pub const ACC_SYNTHETIC = 0x1000;
    pub const ACC_ANNOTATION = 0x2000;
    pub const ACC_ENUM = 0x4000;

    pub const flags = [_][]const u8{
        "ACC_PUBLIC",
        "ACC_FINAL",
        "ACC_SUPER",
        "ACC_INTERFACE",
        "ACC_ABSTRACT",
        "ACC_SYNTHETIC",
        "ACC_ANNOTATION",
        "ACC_ENUM",
    };

    pub const values = [_]u16{
        ACC_PUBLIC,
        ACC_FINAL,
        ACC_SUPER,
        ACC_INTERFACE,
        ACC_ABSTRACT,
        ACC_SYNTHETIC,
        ACC_ANNOTATION,
        ACC_ENUM,
    };
};

pub const MethodAccessFlags = struct {
    pub const ACC_PUBLIC = 0x0001;
    pub const ACC_PRIVATE = 0x0002;
    pub const ACC_PROTECTED = 0x0004;
    pub const ACC_STATIC = 0x0008;
    pub const ACC_FINAL = 0x0010;
    pub const ACC_SYNCHRONIZED = 0x0020;
    pub const ACC_BRIDGE = 0x0040;
    pub const ACC_VARARGS = 0x0080;
    pub const ACC_NATIVE = 0x0100;
    pub const ACC_ABSTRACT = 0x0400;
    pub const ACC_STRICT = 0x0800;
    pub const ACC_SYNTHETIC = 0x1000;

    pub const flags = [_][]const u8{
        "ACC_PUBLIC",
        "ACC_PRIVATE",
        "ACC_PROTECTED",
        "ACC_STATIC",
        "ACC_FINAL",
        "ACC_SYNCHRONIZED",
        "ACC_BRIDGE",
        "ACC_VARARGS",
        "ACC_NATIVE",
        "ACC_ABSTRACT",
        "ACC_STRICT",
        "ACC_SYNTHETIC",
    };

    pub const values = [_]u16{
        ACC_PUBLIC,
        ACC_PRIVATE,
        ACC_PROTECTED,
        ACC_STATIC,
        ACC_FINAL,
        ACC_SYNCHRONIZED,
        ACC_BRIDGE,
        ACC_VARARGS,
        ACC_NATIVE,
        ACC_ABSTRACT,
        ACC_STRICT,
        ACC_SYNTHETIC,
    };
};
