const std = @import("std");
const bufferedReader = @import("std").io.bufferedReader;
const Reader = @import("std").io.AnyReader;
const BigEndian = @import("std").builtin.Endian.big;

const t_u4 = u32;
const t_u2 = u16;
const t_u1 = u8;

const ClassFile = struct {
    magic: t_u4,
    minor_version: t_u2,
    major_version: t_u2,
    constant_pool_count: t_u2,
    cp_info: []cp_info,
    access_flags: []const []const u8,
    this_class: t_u2,
    super_class: t_u2,
    interfaces: []interfaces,
    methods: []method_info,
    attributes: []attribute_info,
};

const interfaces = struct {};

const method_info = struct {
    access_flags: []const []const u8,
    name_index: t_u2,
    descriptor_index: t_u2,
    attributes_count: t_u2,
    attributes: []attribute_info,
};

const attribute_info = struct {
    attribute_name_index: t_u2,
    attribute_length: t_u4,
    info: []t_u1,
};

const cp_info = struct {
    tag: ConstantPoolTags,
    info: []ConstantInfo,
};

const bufPrint = std.fmt.bufPrint;
const allocator = std.heap.page_allocator;

const ConstantPoolTags = enum(t_u1) {
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

    fn fromInt(tag: u8) !ConstantPoolTags {
        return std.meta.intToEnum(ConstantPoolTags, tag);
    }
};

const ConstantInfo = struct { tag: t_u1, class_index: t_u2, name_and_type_index: t_u2, descriptor_index: t_u2, bytes: []t_u1, bytes_length: t_u2, string_index: t_u2, name_index: t_u2 };

const ClassAccessFlags = struct {
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

const MethodAccessFlags = struct {
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

fn parseFlags(value: u16, flags: []const []const u8, values: []const u16) ![]const []const u8 {
    var list = std.ArrayList([]const u8).init(allocator);
    for (flags, values) |flag, val| {
        if ((value & val) != 0) {
            try list.append(flag);
        }
    }
    return list.toOwnedSlice();
}

pub fn main() !void {
    const file = "Main.class";
    const filePointer = try std.fs.cwd().openFile(file, .{ .mode = .read_only });
    defer filePointer.close();

    var BuffReader = bufferedReader(filePointer.reader());
    var reader = BuffReader.reader().any();

    var conf: ClassFile = .{
        .magic = try reader.readInt(t_u4, BigEndian),
        .minor_version = try reader.readInt(t_u2, BigEndian),
        .major_version = try reader.readInt(t_u2, BigEndian),
        .constant_pool_count = try reader.readInt(t_u2, BigEndian),
        .cp_info = undefined,
        .access_flags = undefined,
        .this_class = 0,
        .super_class = 0,
        .interfaces = undefined,
        .methods = undefined,
        .attributes = undefined,
    };

    std.debug.print("Magic: {x}\n", .{conf.magic});
    std.debug.print("Minor Version: {d}\n", .{conf.minor_version});
    std.debug.print("Major Version: {d}\n", .{conf.major_version});
    std.debug.print("Constant Pool Count: {d}\n", .{conf.constant_pool_count});

    conf.cp_info = try allocator.alloc(cp_info, conf.constant_pool_count);
    defer allocator.free(conf.cp_info);

    var index: u16 = 0;
    while (index < conf.constant_pool_count - 1) : (index += 1) {
        std.debug.print("Index: {d}\n", .{index + 1});
        const tag: u8 = try reader.readInt(u8, BigEndian);
        const convertedTag = ConstantPoolTags.fromInt(tag) catch {
            std.debug.panic("Unexpected tag: {d}", .{tag});
        };
        std.debug.print("Tag: {d}\n", .{tag});
        conf.cp_info[index].tag = convertedTag;
        conf.cp_info[index].info = try allocator.alloc(ConstantInfo, 1);
        defer allocator.free(conf.cp_info[index].info);
        var cpInfo: ConstantInfo = undefined;
        cpInfo.tag = tag;
        if (convertedTag == ConstantPoolTags.CONSTANT_Methodref) {
            cpInfo.class_index = try reader.readInt(u16, BigEndian);
            cpInfo.name_and_type_index = try reader.readInt(u16, BigEndian);
            std.debug.print("ClassIndex: {d}\n", .{cpInfo.class_index});
            std.debug.print("NameAndTypeIndex: {d}\n", .{cpInfo.name_and_type_index});
        } else if (convertedTag == ConstantPoolTags.CONSTANT_Class) {
            cpInfo.name_index = try reader.readInt(u16, BigEndian);
            std.debug.print("NameIndex: {d}\n", .{cpInfo.name_index});
        } else if (convertedTag == ConstantPoolTags.CONSTANT_NameAndType) {
            cpInfo.name_index = try reader.readInt(u16, BigEndian);
            cpInfo.descriptor_index = try reader.readInt(u16, BigEndian);
            std.debug.print("NameIndex: {d}\n", .{cpInfo.name_index});
            std.debug.print("DescriptorIndex: {d}\n", .{cpInfo.descriptor_index});
        } else if (convertedTag == ConstantPoolTags.CONSTANT_Utf8) {
            const length = try reader.readInt(u16, BigEndian);
            cpInfo.bytes = try allocator.alloc(u8, length);
            defer allocator.free(cpInfo.bytes);
            _ = try reader.read(cpInfo.bytes);
            cpInfo.bytes_length = length;
            const str = cpInfo.bytes[0..length];
            std.debug.print("Utf8: {s}\n", .{str});
        } else if (convertedTag == ConstantPoolTags.CONSTANT_Fieldref) {
            cpInfo.class_index = try reader.readInt(u16, BigEndian);
            cpInfo.name_and_type_index = try reader.readInt(u16, BigEndian);
            std.debug.print("ClassIndex: {d}\n", .{cpInfo.class_index});
            std.debug.print("NameAndTypeIndex: {d}\n", .{cpInfo.name_and_type_index});
        } else if (convertedTag == ConstantPoolTags.CONSTANT_String) {
            cpInfo.string_index = try reader.readInt(u16, BigEndian);
            std.debug.print("string_index: {d}\n", .{cpInfo.string_index});
        } else {
            std.debug.panic("Unexpected tag: {any}", .{convertedTag});
        }
        std.debug.print("\n", .{});

        conf.cp_info[index].info[0] = cpInfo;
    }

    const access_flags = try reader.readInt(u16, BigEndian);
    conf.access_flags = try parseFlags(access_flags, &ClassAccessFlags.flags, &ClassAccessFlags.values);
    conf.this_class = try reader.readInt(u16, BigEndian);
    conf.super_class = try reader.readInt(u16, BigEndian);

    const interfacesCount = try reader.readInt(u16, BigEndian);
    var loop: u16 = 0;
    while (loop < interfacesCount) : (loop += 1) {
        @panic("We do not support interfaces yet...");
    }

    const fieldsCount = try reader.readInt(t_u2, BigEndian);
    loop = 0;
    while (loop < fieldsCount) : (loop += 1) {
        @panic("We do not support fields yet...");
    }

    const methodsCount = try reader.readInt(t_u2, BigEndian);

    conf.methods = try parse_methods(reader, methodsCount);
    std.debug.print("Methods Count: {d}\n", .{methodsCount});

    const attCount = try reader.readInt(t_u2, BigEndian);
    conf.attributes = try parse_attributes(reader, attCount);
}

pub fn parse_methods(reader: anytype, methods_count: t_u2) ![]method_info {
    var loop: t_u2 = 0;
    var ret = try allocator.alloc(method_info, methods_count);
    defer allocator.free(ret);
    while (loop < methods_count) : (loop += 1) {
        var meth: method_info = undefined;
        meth.access_flags = try parseFlags(try reader.readInt(t_u2, BigEndian), &MethodAccessFlags.flags, &MethodAccessFlags.values);
        meth.name_index = try reader.readInt(t_u2, BigEndian);
        meth.descriptor_index = try reader.readInt(t_u2, BigEndian);
        meth.attributes_count = try reader.readInt(t_u2, BigEndian);
        meth.attributes = try parse_attributes(reader, meth.attributes_count);
        ret[loop] = meth;
    }
    return ret;
}

pub fn parse_attributes(reader: anytype, attribute_count: t_u2) ![]attribute_info {
    var loop: t_u2 = 0;
    var ret = try allocator.alloc(attribute_info, attribute_count);
    defer allocator.free(ret);
    while (loop < attribute_count) : (loop += 1) {
        var att: attribute_info = undefined;
        att.attribute_name_index = try reader.readInt(t_u2, BigEndian);
        att.attribute_length = try reader.readInt(t_u4, BigEndian);
        att.info = try allocator.alloc(t_u1, att.attribute_length);
        defer allocator.free(att.info);
        _ = try reader.read(att.info);
        std.debug.print("AttInfo: {x}\n", .{att.info[0..att.attribute_length]});
        ret[loop] = att;
    }
    return ret;
}
