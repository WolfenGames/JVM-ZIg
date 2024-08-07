const std = @import("std");
const bufferedReader = @import("std").io.bufferedReader;

const ClassFile = struct {
    magic: u32,
    minor_version: u16,
    major_version: u16,
    constant_pool_count: u16,
    cp_info: []cp_info,
    access_flags: u16,
    this_class: u16,
    super_class: u16,
    methods: []method_info,
};

const method_info = struct {
    access_flags: u16,
    name_index: u16,
    descriptor_index: u16,
    attributes_count: u16,
    attributes: []attribute_info,
};

const attribute_info = struct {
    attribute_name_index: u16,
    attribute_length: u32,
};

const cp_info = struct {
    tag: ConstantPoolTags,
    info: []ConstantInfo,
};

const bufPrint = std.fmt.bufPrint;
const allocator = std.heap.page_allocator;

const ConstantPoolTags = enum(u8) {
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

const ConstantInfo = struct { tag: u8, class_index: u16, name_and_type_index: u16, descriptor_index: u16, bytes: []u8, string_index: u16, name_index: u16 };

pub fn main() !void {
    const file = "Main.class";
    const filePointer = try std.fs.cwd().openFile(file, .{ .mode = .read_only });
    defer filePointer.close();

    var BuffReader = bufferedReader(filePointer.reader());
    var reader = BuffReader.reader().any();

    var conf: ClassFile = .{
        .magic = try reader.readInt(u32, std.builtin.Endian.big),
        .minor_version = try reader.readInt(u16, std.builtin.Endian.big),
        .major_version = try reader.readInt(u16, std.builtin.Endian.big),
        .constant_pool_count = try reader.readInt(u16, std.builtin.Endian.big),
        .cp_info = undefined,
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
        const tag: u8 = try reader.readInt(u8, std.builtin.Endian.big);
        const convertedTag = ConstantPoolTags.fromInt(tag) catch {
            std.debug.panic("Unexpected tag: {d}", .{tag});
        };
        std.debug.print("Tag: {d}\n", .{tag});
        conf.cp_info[index].tag = convertedTag;
        conf.cp_info[index].info = try allocator.alloc(ConstantInfo, 1);
        var cpInfo: ConstantInfo = undefined;
        cpInfo.tag = tag;
        if (convertedTag == ConstantPoolTags.CONSTANT_Methodref) {
            cpInfo.class_index = try reader.readInt(u16, std.builtin.Endian.big);
            cpInfo.name_and_type_index = try reader.readInt(u16, std.builtin.Endian.big);
        } else if (convertedTag == ConstantPoolTags.CONSTANT_Class) {
            cpInfo.name_index = try reader.readInt(u16, std.builtin.Endian.big);
        } else if (convertedTag == ConstantPoolTags.CONSTANT_NameAndType) {
            cpInfo.name_index = try reader.readInt(u16, std.builtin.Endian.big);
            cpInfo.descriptor_index = try reader.readInt(u16, std.builtin.Endian.big);
        } else if (convertedTag == ConstantPoolTags.CONSTANT_Utf8) {
            const length = try reader.readInt(u16, std.builtin.Endian.big);
            cpInfo.bytes = try allocator.alloc(u8, length);
            _ = try reader.read(cpInfo.bytes);
        } else if (convertedTag == ConstantPoolTags.CONSTANT_Fieldref) {
            cpInfo.class_index = try reader.readInt(u16, std.builtin.Endian.big);
            cpInfo.name_and_type_index = try reader.readInt(u16, std.builtin.Endian.big);
        } else if (convertedTag == ConstantPoolTags.CONSTANT_String) {
            cpInfo.string_index = try reader.readInt(u16, std.builtin.Endian.big);
        } else {
            std.debug.panic("Unexpected tag: {any}", .{convertedTag});
        }
        std.debug.print("\n", .{});

        conf.cp_info[index].info[0] = cpInfo;

        conf.access_flags = try reader.readInt(u16, std.builtin.Endian.big);
        conf.this_class = try reader.readInt(u16, std.builtin.Endian.big);
    }
}
