const std = @import("std");

const lib = @import("lib");

const cap = lib.cap;
const draw = lib.draw;
const sys = lib.sys;

const Handle = cap.Handle;

const page_size = 4096;
const control_capacity = 32 * 1024;
const stream_capacity = 16 * 1024;

const context_id: u32 = 1;
const first_resource_id: u32 = 0x1000_0000;

const cmd_get_capset_info: u32 = 0x0108;
const cmd_get_capset: u32 = 0x0109;
const cmd_ctx_create: u32 = 0x0200;
const cmd_ctx_destroy: u32 = 0x0201;
const cmd_ctx_attach_resource: u32 = 0x0202;
const cmd_ctx_detach_resource: u32 = 0x0203;
const cmd_resource_create_3d: u32 = 0x0204;
const cmd_transfer_to_host_3d: u32 = 0x0205;
const cmd_transfer_from_host_3d: u32 = 0x0206;
const cmd_submit_3d: u32 = 0x0207;

const resp_ok_nodata: u32 = 0x1100;
const resp_ok_capset_info: u32 = 0x1102;
const resp_ok_capset: u32 = 0x1103;

const flag_fence: u32 = 1;

const capset_virgl: u32 = 1;
const capset_virgl2: u32 = 2;

const target_buffer: u32 = 0;
const target_texture_2d: u32 = 2;

const format_b8g8r8a8: u32 = 1;
const format_b8g8r8x8: u32 = 2;
const format_r32g32_float: u32 = 29;
const format_r8_unorm: u32 = 64;
const format_r8g8_snorm: u32 = 75;

const bind_render_target: u32 = 1 << 1;
const bind_sampler_view: u32 = 1 << 3;
const bind_vertex_buffer: u32 = 1 << 4;
const bind_display_target: u32 = 1 << 7;
const bind_scanout: u32 = 1 << 18;

const resource_y_0_top: u32 = 1;

const object_blend: u32 = 1;
const object_rasterizer: u32 = 2;
const object_dsa: u32 = 3;
const object_shader: u32 = 4;
const object_vertex_elements: u32 = 5;
const object_sampler_view: u32 = 6;
const object_sampler_state: u32 = 7;
const object_surface: u32 = 8;

const ccmd_create_object: u32 = 1;
const ccmd_bind_object: u32 = 2;
const ccmd_destroy_object: u32 = 3;
const ccmd_set_viewport_state: u32 = 4;
const ccmd_set_framebuffer_state: u32 = 5;
const ccmd_set_vertex_buffers: u32 = 6;
const ccmd_clear: u32 = 7;
const ccmd_draw_vbo: u32 = 8;
const ccmd_set_sampler_views: u32 = 10;
const ccmd_set_constant_buffer: u32 = 12;
const ccmd_bind_sampler_states: u32 = 18;
const ccmd_bind_shader: u32 = 31;
const ccmd_link_shader: u32 = 52;

const shader_vertex: u32 = 0;
const shader_fragment: u32 = 1;
const primitive_triangles: u32 = 4;
const clear_color_0: u32 = 1 << 2;

const vertex_shader_handle: u32 = 1;
const copy_shader_handle: u32 = 2;
const blur_h_light_handle: u32 = 3;
const blur_v_light_handle: u32 = 4;
const blur_h_regular_handle: u32 = 5;
const blur_v_regular_handle: u32 = 6;
const blur_h_prominent_handle: u32 = 7;
const blur_v_prominent_handle: u32 = 8;
const resolve_shader_handle: u32 = 9;

const blend_handle: u32 = 20;
const dsa_handle: u32 = 21;
const rasterizer_handle: u32 = 22;
const vertex_elements_handle: u32 = 23;
const sampler_handle: u32 = 24;

// Virgl object handles share one namespace. Each workspace owns one contiguous
// block (3 surfaces + 5 sampler views). Separating surface/view bases by a
// fixed offset (100 vs 120) collides once capacity > 2 — e.g. workspace 3's
// surface 124 overwrites workspace 0's displacement view 124 ("Illegal handle 124").
const workspace_capacity: usize = 4;
const workspace_surface_count: u32 = 3;
const workspace_view_count: u32 = 5;
const workspace_handle_stride: u32 = workspace_surface_count + workspace_view_count;
const transient_object_base: u32 = 100;
const proof_surface_handle: u32 = transient_object_base;
const proof_view_handle: u32 = transient_object_base + 1;

const frost_scale: u32 = 2;
const frost_radius_light: u32 = 3;
const frost_radius_regular: u32 = 5;
const frost_radius_prominent: u32 = 8;
const max_refraction_pixels: u32 = 21;
const chroma_radius: u32 = 2;
const displacement_scale: f32 = 127.0 * 13.0 / (5.0 * 16.0);

const CtrlHeader = extern struct {

    kind: u32,
    flags: u32,

    fence_id: u64,
    ctx_id: u32,

    ring_idx: u8,
    padding: [3]u8,

};

const GetCapsetInfo = extern struct {

    header: CtrlHeader,
    index: u32,
    padding: u32,

};

const CapsetInfo = extern struct {

    header: CtrlHeader,

    id: u32,
    max_version: u32,
    max_size: u32,
    padding: u32,

};

const GetCapset = extern struct {

    header: CtrlHeader,
    id: u32,
    version: u32,

};

const ContextCreate = extern struct {

    header: CtrlHeader,

    name_length: u32,
    context_init: u32,
    debug_name: [64]u8,

};

const ContextResource = extern struct {

    header: CtrlHeader,
    resource_id: u32,
    padding: u32,

};

const ResourceCreate3d = extern struct {

    header: CtrlHeader,

    resource_id: u32,
    target: u32,
    format: u32,
    bind: u32,

    width: u32,
    height: u32,
    depth: u32,
    array_size: u32,

    last_level: u32,
    samples: u32,
    flags: u32,
    padding: u32,

};

const AttachBacking = extern struct {

    header: CtrlHeader,

    resource_id: u32,
    entry_count: u32,

    address: u64,
    length: u32,
    entry_padding: u32,

};

const ResourceUnref = extern struct {

    header: CtrlHeader,
    resource_id: u32,
    padding: u32,

};

const GpuBox = extern struct {

    x: u32,
    y: u32,
    z: u32,

    width: u32,
    height: u32,
    depth: u32,

};

const Transfer3d = extern struct {

    header: CtrlHeader,
    box: GpuBox,

    offset: u64,

    resource_id: u32,
    level: u32,
    stride: u32,
    layer_stride: u32,

};

const Submit3d = extern struct {

    header: CtrlHeader,
    size: u32,
    padding: u32,

};

pub const NodataRequest = struct {

    bytes: []const u8,

};

pub const Transport = struct {

    submit: *const fn (bytes: []const u8, response: []u8) anyerror!u32,
    submit_nodata_batch: *const fn (requests: []const NodataRequest) anyerror!void,
    present: *const fn (resource_id: u32, width: u32, height: u32) anyerror!void,
    restore_scanout: *const fn () anyerror!void,

};

pub const Rect = struct {

    x: u32,
    y: u32,
    width: u32,
    height: u32,

};

pub const Metrics = struct {

    resolves: u64 = 0,
    pixels: u64 = 0,
    backdrop_captures: u64 = 0,
    blur_passes: u64 = 0,
    submissions: u64 = 0,
    readbacks: u64 = 0,
    workspace_hits: u64 = 0,
    elapsed_ns: u64 = 0,

};

const DmaBuffer = struct {

    region: Handle = 0,
    base: usize = 0,
    physical: u64 = 0,
    bytes: usize = 0,

    fn allocate(bytes: usize) !DmaBuffer {

        if (bytes == 0) return error.Invalid;

        const padded = std.math.add(usize, bytes, page_size - 1) catch return error.TooLarge;
        const aligned = padded & ~@as(usize, page_size - 1);
        const dma = try sys.create_dma(aligned, cap.driver.dma);
        const base = sys.map(cap.self_space, dma.region, 0, sys.read | sys.write) catch |failure| {

            sys.close(dma.region) catch {};

            return failure;

        };

        @memset(@as([*]u8, @ptrFromInt(base))[0..aligned], 0);

        return .{

            .region = dma.region,
            .base = base,
            .physical = dma.physical_base,
            .bytes = bytes,

        };

    }

    fn release(self: *DmaBuffer) void {

        if (self.base != 0) sys.unmap(cap.self_space, self.base) catch {};
        if (self.region != 0) sys.close(self.region) catch {};

        self.* = .{};

    }

};

const Texture = struct {

    resource_id: u32 = 0,
    width: u32 = 0,
    height: u32 = 0,
    format: u32 = 0,
    bytes_per_pixel: u32 = 0,
    backing: DmaBuffer = .{},

};

const Workspace = struct {

    valid: bool = false,
    objects_ready: bool = false,
    frost_ready: bool = false,
    last_used: u64 = 0,
    surface_base: u32 = 0,
    view_base: u32 = 0,

    scene_x: u32 = 0,
    scene_y: u32 = 0,
    scene_width: u32 = 0,
    scene_height: u32 = 0,
    half_width: u32 = 0,
    half_height: u32 = 0,
    visible_x: u32 = 0,
    visible_y: u32 = 0,
    visible_width: u32 = 0,
    visible_height: u32 = 0,
    density: u8 = 0,

    raw_scene: Texture = .{},
    frost_a: Texture = .{},
    frost_b: Texture = .{},
    material: Texture = .{},
    displacement: Texture = .{},
    output: Texture = .{},

    fn matches(self: *const Workspace, scene: Rect, half_width: u32, half_height: u32, visible: Rect) bool {

        return self.valid and
            self.scene_width == scene.width and self.scene_height == scene.height and
            self.half_width == half_width and self.half_height == half_height and
            self.visible_width == visible.width and self.visible_height == visible.height;

    }

    // Frost is only reusable when the same screen placement and density produced it.
    fn frost_reusable(self: *const Workspace, scene: Rect, visible: Rect, density: u8) bool {

        return self.frost_ready and self.density == density and
            self.scene_x == scene.x and self.scene_y == scene.y and
            self.visible_x == visible.x and self.visible_y == visible.y;

    }

};

const Stream = struct {

    words: [stream_capacity / @sizeOf(u32)]u32 = undefined,
    len: usize = 0,

    fn reset(self: *Stream) void {

        self.len = 0;

    }

    fn push(self: *Stream, value: u32) !void {

        if (self.len == self.words.len) return error.TooLarge;

        self.words[self.len] = value;
        self.len += 1;

    }

    fn command(self: *Stream, command_id: u32, object: u32, length: u32) !void {

        try self.push(command_id | (object << 8) | (length << 16));

    }

    fn float(self: *Stream, value: f32) !void {

        try self.push(@bitCast(value));

    }

    fn bytes(self: *const Stream) []const u8 {

        return std.mem.sliceAsBytes(self.words[0..self.len]);

    }

};

pub const Renderer = struct {

    transport: Transport = undefined,
    initialized: bool = false,
    context_init: bool = false,
    capset_id: u32 = 0,

    next_resource_id: u32 = first_resource_id,
    next_fence_id: u64 = 1,

    vertex_buffer: Texture = .{},
    workspaces: [workspace_capacity]Workspace = [_]Workspace{.{}} ** workspace_capacity,
    workspace_clock: u64 = 0,

    control: [control_capacity]u8 = undefined,
    shader_command: [control_capacity]u8 = undefined,
    stream: Stream = .{},
    shader_text: [12 * 1024]u8 = undefined,

    metrics: Metrics = .{},

    pub fn initialize(self: *Renderer, transport: Transport, capset_count: u32, context_init: bool) !void {

        self.transport = transport;
        self.context_init = context_init;

        self.discover_capset(capset_count) catch |failure| {

            lib.log.fmt("Quartz GPU init: capset failed: {s}\n", .{@errorName(failure)});

            return failure;

        };
        self.initialized = true;
        errdefer self.shutdown();

        self.create_context() catch |failure| {

            lib.log.fmt("Quartz GPU init: context failed: {s}\n", .{@errorName(failure)});

            return failure;

        };
        self.create_static_pipeline() catch |failure| {

            lib.log.fmt("Quartz GPU init: pipeline failed: {s}\n", .{@errorName(failure)});

            return failure;

        };

    }

    pub fn shutdown(self: *Renderer) void {

        if (!self.initialized) {

            self.* = .{};

            return;

        }

        for (&self.workspaces) |*workspace| {

            self.release_workspace(workspace);

        }
        self.release_texture(&self.vertex_buffer);

        const destroy_request = self.context_header(cmd_ctx_destroy, true);
        _ = self.control_struct(CtrlHeader, destroy_request, self.control[0..0]) catch {};

        const saved_transport = self.transport;
        const saved_metrics = self.metrics;

        self.* = .{};
        self.transport = saved_transport;
        self.metrics = saved_metrics;

    }

    pub fn ready(self: *const Renderer) bool {

        return self.initialized;

    }

    pub fn reset_for_resize(self: *Renderer, width: u32, height: u32) !void {

        if (!self.initialized) return;

        const transport = self.transport;
        const context_init = self.context_init;
        const capset_id = self.capset_id;
        const metrics = self.metrics;

        self.shutdown();

        self.transport = transport;
        self.context_init = context_init;
        self.capset_id = capset_id;
        self.metrics = metrics;

        self.initialized = true;
        errdefer self.shutdown();

        try self.create_context();
        try self.create_static_pipeline();
        try self.proof(width, height);

    }

    pub fn snapshot_metrics(self: *const Renderer) Metrics {

        return self.metrics;

    }

    pub fn proof(self: *Renderer, width: u32, height: u32) !void {

        if (!self.initialized or width == 0 or height == 0) return error.Invalid;

        var source = try self.create_texture(2, 2, format_b8g8r8x8, bind_sampler_view, 4, target_texture_2d);
        defer self.release_texture(&source);

        var target = try self.create_texture(
            width,
            height,
            format_b8g8r8a8,
            bind_render_target | bind_sampler_view | bind_display_target | bind_scanout,
            4,
            target_texture_2d,
        );
        defer self.release_texture(&target);

        const pixels: [*]u32 = @ptrFromInt(source.backing.base);
        pixels[0] = 0x0020_70d0;
        pixels[1] = 0x00d0_7040;
        pixels[2] = 0x00d0_7040;
        pixels[3] = 0x0020_70d0;

        try self.upload(&source);

        self.stream.reset();

        try self.create_surface(proof_surface_handle, &target);
        try self.create_view(proof_view_handle, &source);
        try self.set_framebuffer(proof_surface_handle);
        try self.set_viewport(width, height);
        try self.clear(0, 0, 0, 1.0);
        try self.draw(copy_shader_handle, &.{proof_view_handle}, &.{});

        defer self.destroy_objects(proof_surface_handle, 1, proof_view_handle, 1);

        try self.submit_stream();

        // SUBMIT_3D only acknowledges transport completion.  A virglrenderer
        // context error is reported by the host out of band, so prove that the
        // shaders actually drew before advertising the renderer as available.
        try self.readback(&target);

        const target_pixels: [*]const u32 = @ptrFromInt(target.backing.base);
        const center = @as(usize, height / 2) * @as(usize, width) + @as(usize, width / 2);

        if (target_pixels[center] & 0x00ff_ffff == 0) return error.ProofMismatch;

        try self.transport.present(target.resource_id, width, height);
        try self.transport.restore_scanout();

    }

    pub fn composite(
        self: *Renderer,
        back: [*]u32,
        back_stride: u32,
        foreground: [*]const u32,
        effect: [*]const u8,
        surface_width: u32,
        surface_height: u32,
        visible: Rect,
        source_x: u32,
        source_y: u32,
        screen_width: u32,
        screen_height: u32,
        density: u8,
        material_only: bool,
    ) !void {

        if (!self.initialized) return error.Unsupported;
        if (visible.width == 0 or visible.height == 0) return;
        if (source_x > surface_width or visible.width > surface_width - source_x) return error.Invalid;
        if (source_y > surface_height or visible.height > surface_height - source_y) return error.Invalid;
        if (visible.x > screen_width or visible.width > screen_width - visible.x) return error.Invalid;
        if (visible.y > screen_height or visible.height > screen_height - visible.y) return error.Invalid;

        const started = lib.time.now_ns();
        const halo = damage_halo(density);
        const scene = expand(visible, halo, screen_width, screen_height);
        const half_width = (scene.width + frost_scale - 1) / frost_scale;
        const half_height = (scene.height + frost_scale - 1) / frost_scale;
        const workspace = try self.acquire_workspace(scene, half_width, half_height, visible);
        const reuse_frost = material_only and workspace.frost_reusable(scene, visible, density);

        if (!reuse_frost) capture_backdrop(&workspace.raw_scene, back, back_stride, scene);

        capture_material(&workspace.material, &workspace.displacement, foreground, effect, surface_width, source_x, source_y, visible.width, visible.height);

        return self.resolve_workspace(back, back_stride, visible, scene, half_width, half_height, density, workspace, started, reuse_frost);

    }

    fn resolve_workspace(
        self: *Renderer,
        back: [*]u32,
        back_stride: u32,
        visible: Rect,
        scene: Rect,
        half_width: u32,
        half_height: u32,
        density: u8,
        workspace: *Workspace,
        started: u64,
        reuse_frost: bool,
    ) !void {

        // Hover/material updates keep GPU frost when placement matches; only re-upload glass + resolve.
        if (reuse_frost) {

            try self.upload_many(&.{ &workspace.material, &workspace.displacement });

        } else {

            try self.upload_many(&.{ &workspace.raw_scene, &workspace.material, &workspace.displacement });

        }

        self.stream.reset();

        if (!reuse_frost) {

            const radius = frost_radius(density);
            const blur_handles = blur_shader_handles(radius);

            try self.set_framebuffer(workspace.surface_base);
            try self.set_viewport(half_width, half_height);
            try self.draw(blur_handles.horizontal, &.{workspace.view_base}, &.{

                2.0 / @as(f32, @floatFromInt(scene.width)),
                2.0 / @as(f32, @floatFromInt(scene.height)),
                2.0 * @as(f32, @floatFromInt(half_width)) / @as(f32, @floatFromInt(scene.width)),
                2.0 * @as(f32, @floatFromInt(half_height)) / @as(f32, @floatFromInt(scene.height)),

            });

            try self.set_framebuffer(workspace.surface_base + 1);
            try self.draw(blur_handles.vertical, &.{workspace.view_base + 1}, &.{

                1.0 / @as(f32, @floatFromInt(half_width)),
                1.0 / @as(f32, @floatFromInt(half_height)),
                1,
                1,

            });

        }

        const scene_width_f: f32 = @floatFromInt(scene.width);
        const scene_height_f: f32 = @floatFromInt(scene.height);
        const half_width_f: f32 = @floatFromInt(half_width);
        const half_height_f: f32 = @floatFromInt(half_height);
        const scene_offset_x: f32 = @floatFromInt(visible.x - scene.x);
        const scene_offset_y: f32 = @floatFromInt(visible.y - scene.y);
        try self.set_framebuffer(workspace.surface_base + 2);
        try self.set_viewport(visible.width, visible.height);
        try self.draw(resolve_shader_handle, &.{

            workspace.view_base,
            workspace.view_base + 2,
            workspace.view_base + 3,
            workspace.view_base + 4,

        }, &.{

            @as(f32, @floatFromInt(visible.width)) / scene_width_f,
            @as(f32, @floatFromInt(visible.height)) / scene_height_f,
            scene_offset_x / scene_width_f,
            scene_offset_y / scene_height_f,

            displacement_scale / scene_width_f,
            displacement_scale / scene_height_f,
            0,
            0,

            1.5 / scene_width_f,
            1.5 / scene_height_f,
            0,
            0,

            0.45,
            0,
            0,
            0,

            @as(f32, @floatFromInt(visible.width)) / (2.0 * half_width_f),
            @as(f32, @floatFromInt(visible.height)) / (2.0 * half_height_f),
            (scene_offset_x + 0.5) / (2.0 * half_width_f),
            (scene_offset_y + 0.5) / (2.0 * half_height_f),

            displacement_scale / (2.0 * half_width_f),
            displacement_scale / (2.0 * half_height_f),
            0,
            0,

        });

        try self.submit_stream();

        try self.readback(&workspace.output);

        copy_output(back, back_stride, visible, &workspace.output);

        workspace.scene_x = scene.x;
        workspace.scene_y = scene.y;
        workspace.visible_x = visible.x;
        workspace.visible_y = visible.y;
        workspace.density = density;
        workspace.frost_ready = true;

        self.metrics.resolves += 1;
        self.metrics.pixels += @as(u64, visible.width) * visible.height;
        self.metrics.elapsed_ns += lib.time.now_ns() - started;

        if (!reuse_frost) {

            self.metrics.backdrop_captures += 1;
            self.metrics.blur_passes += 2;

        }

    }

    pub fn composite_header(
        self: *Renderer,
        back: [*]u32,
        back_stride: u32,
        visible: Rect,
        source_x: u32,
        source_y: u32,
        header_width: u32,
        header_height: u32,
        tint: u32,
        opacity: u8,
        radius: u8,
        joined: bool,
        density: u8,
        screen_width: u32,
        screen_height: u32,
        material_only: bool,
    ) !void {

        if (visible.width == 0 or visible.height == 0) return;
        if (source_x > header_width or visible.width > header_width - source_x) return error.Invalid;
        if (source_y > header_height or visible.height > header_height - source_y) return error.Invalid;
        if (visible.x > screen_width or visible.width > screen_width - visible.x) return error.Invalid;
        if (visible.y > screen_height or visible.height > screen_height - visible.y) return error.Invalid;

        const started = lib.time.now_ns();
        const halo = damage_halo(density);
        const scene = expand(visible, halo, screen_width, screen_height);
        const half_width = (scene.width + frost_scale - 1) / frost_scale;
        const half_height = (scene.height + frost_scale - 1) / frost_scale;
        const workspace = try self.acquire_workspace(scene, half_width, half_height, visible);
        const reuse_frost = material_only and workspace.frost_reusable(scene, visible, density);
        const foreground: [*]u32 = @ptrFromInt(workspace.material.backing.base);
        const effect: [*]u8 = @ptrFromInt(workspace.displacement.backing.base);

        build_header_material(
            foreground,
            effect,
            visible.width,
            visible.height,
            source_x,
            source_y,
            header_width,
            header_height,
            tint,
            opacity,
            radius,
            joined,
        );

        if (!reuse_frost) capture_backdrop(&workspace.raw_scene, back, back_stride, scene);

        capture_material(&workspace.material, &workspace.displacement, foreground, effect, visible.width, 0, 0, visible.width, visible.height);

        try self.resolve_workspace(back, back_stride, visible, scene, half_width, half_height, density, workspace, started, reuse_frost);

    }

    fn discover_capset(self: *Renderer, capset_count: u32) !void {

        var chosen = CapsetInfo{

            .header = zero_header(),

            .id = 0,
            .max_version = 0,
            .max_size = 0,
            .padding = 0,

        };

        var response: [4096]u8 = undefined;
        var index: u32 = 0;

        while (index < capset_count) : (index += 1) {

            @memset(&response, 0);

            const request = GetCapsetInfo{

                .header = self.header(cmd_get_capset_info, false),
                .index = index,
                .padding = 0,

            };

            const kind = try self.submit_struct(GetCapsetInfo, request, &response);

            if (kind != resp_ok_capset_info) continue;

            const info = std.mem.bytesToValue(CapsetInfo, response[0..@sizeOf(CapsetInfo)]);

            if (info.id != capset_virgl and info.id != capset_virgl2) continue;
            if (chosen.id == capset_virgl2) continue;

            chosen = info;

        }

        if (chosen.id == 0) return error.NoVirglCapset;
        if (@as(usize, chosen.max_size) + @sizeOf(CtrlHeader) > response.len) return error.CapsetTooLarge;

        lib.log.fmt("Quartz GPU init: capset id={d} version={d} bytes={d}\n", .{

            chosen.id,
            chosen.max_version,
            chosen.max_size,

        });

        @memset(&response, 0);

        const request = GetCapset{

            .header = self.header(cmd_get_capset, false),
            .id = chosen.id,
            .version = chosen.max_version,

        };

        if (try self.submit_struct(GetCapset, request, &response) != resp_ok_capset) return error.CapsetResponse;

        const data = response[@sizeOf(CtrlHeader)..];

        if (data.len < 260) return error.CapsetTruncated;
        if (!format_supported(data[4..68], format_b8g8r8x8)) return error.MissingBackdropSampler;
        if (!format_supported(data[4..68], format_b8g8r8a8)) return error.MissingMaterialSampler;
        if (!format_supported(data[4..68], format_r8g8_snorm)) return error.MissingDisplacementSampler;
        if (!format_supported(data[68..132], format_b8g8r8a8)) return error.MissingColorTarget;

        self.capset_id = chosen.id;

        const glsl_level = std.mem.readInt(u32, data[264..268], .little);
        const texture_units = if (data.len >= 768) std.mem.readInt(u32, data[764..768], .little) else 0;

        lib.log.fmt("Quartz GPU init: texture formats accepted; baseline vertex format selected; glsl={d} texture_units={d}\n", .{
            glsl_level,
            texture_units,
        });

    }

    fn create_context(self: *Renderer) !void {

        var request = ContextCreate{

            .header = self.context_header(cmd_ctx_create, true),

            .name_length = 14,
            .context_init = if (self.context_init) self.capset_id else 0,
            .debug_name = [_]u8{0} ** 64,

        };

        @memcpy(request.debug_name[0..14], "granite-quartz");

        if (try self.control_struct(ContextCreate, request, self.control[0..0]) != resp_ok_nodata) return error.Unsupported;

    }

    fn create_static_pipeline(self: *Renderer) !void {

        self.vertex_buffer = try self.create_texture(48, 1, format_r8_unorm, bind_vertex_buffer, 1, target_buffer);

        const vertices = [_]f32{

            -1, -1, 0, 0,
            3,  -1, 2, 0,
            -1, 3,  0, 2,

        };
        const vertex_bytes = std.mem.sliceAsBytes(vertices[0..]);
        const destination: [*]u8 = @ptrFromInt(self.vertex_buffer.backing.base);

        @memcpy(destination[0..vertex_bytes.len], vertex_bytes);

        try self.upload(&self.vertex_buffer);

        try self.create_shader(vertex_shader_handle, shader_vertex, vertex_shader);
        try self.create_shader(copy_shader_handle, shader_fragment, copy_shader);
        try self.create_blur_shader(blur_h_light_handle, true, frost_radius_light);
        try self.create_blur_shader(blur_v_light_handle, false, frost_radius_light);
        try self.create_blur_shader(blur_h_regular_handle, true, frost_radius_regular);
        try self.create_blur_shader(blur_v_regular_handle, false, frost_radius_regular);
        try self.create_blur_shader(blur_h_prominent_handle, true, frost_radius_prominent);
        try self.create_blur_shader(blur_v_prominent_handle, false, frost_radius_prominent);

        lib.log.line("Quartz GPU init: resolve shader begin\n");
        try self.create_shader(resolve_shader_handle, shader_fragment, resolve_shader);
        lib.log.line("Quartz GPU init: resolve shader submitted\n");

        self.stream.reset();

        try self.stream.command(ccmd_create_object, object_vertex_elements, 9);
        try self.stream.push(vertex_elements_handle);
        try self.stream.push(0);
        try self.stream.push(0);
        try self.stream.push(0);
        try self.stream.push(format_r32g32_float);
        try self.stream.push(8);
        try self.stream.push(0);
        try self.stream.push(0);
        try self.stream.push(format_r32g32_float);

        try self.bind_object(object_vertex_elements, vertex_elements_handle);

        try self.stream.command(ccmd_create_object, object_blend, 11);
        try self.stream.push(blend_handle);
        try self.stream.push(0);
        try self.stream.push(0);
        try self.stream.push(0xf << 27);

        for (0..7) |_| try self.stream.push(0);

        try self.bind_object(object_blend, blend_handle);

        try self.stream.command(ccmd_create_object, object_dsa, 5);
        try self.stream.push(dsa_handle);
        try self.stream.push(0);
        try self.stream.push(0);
        try self.stream.push(0);
        try self.stream.push(0);

        try self.bind_object(object_dsa, dsa_handle);

        try self.stream.command(ccmd_create_object, object_rasterizer, 9);
        try self.stream.push(rasterizer_handle);
        try self.stream.push((1 << 1) | (1 << 29) | (1 << 30));
        try self.stream.float(1.0);
        try self.stream.push(0);
        try self.stream.push(0);
        try self.stream.float(1.0);
        try self.stream.float(0);
        try self.stream.float(0);
        try self.stream.float(0);

        try self.bind_object(object_rasterizer, rasterizer_handle);

        try self.stream.command(ccmd_create_object, object_sampler_state, 9);
        try self.stream.push(sampler_handle);
        try self.stream.push(2 | (2 << 3) | (2 << 6) | (1 << 9) | (2 << 11) | (1 << 13));
        try self.stream.float(0);
        try self.stream.float(0);
        try self.stream.float(0);

        for (0..4) |_| try self.stream.push(0);

        try self.stream.command(ccmd_set_vertex_buffers, 0, 3);
        try self.stream.push(16);
        try self.stream.push(0);
        try self.stream.push(self.vertex_buffer.resource_id);

        try self.stream.command(ccmd_bind_shader, 0, 2);
        try self.stream.push(vertex_shader_handle);
        try self.stream.push(shader_vertex);

        try self.submit_stream();

    }

    fn create_blur_shader(self: *Renderer, handle: u32, horizontal: bool, radius: u32) !void {

        var used: usize = 0;

        try append_text(&self.shader_text, &used,
            "FRAG\n" ++
                "DCL IN[0], GENERIC[0], LINEAR\n" ++
                "DCL OUT[0], COLOR\n" ++
                "DCL CONST[0]\n" ++
                "DCL SAMP[0]\n" ++
                "DCL SVIEW[0], 2D, FLOAT\n" ++
                "DCL TEMP[0..4]\n");

        const radius_i32: i32 = @intCast(radius);
        const count: f32 = @floatFromInt(radius * 2 + 1);
        try append_format(&self.shader_text, &used, "IMM[0] FLT32 {{{d}.0, 1.0, {d}, 0.0}}\n", .{ -radius_i32, 1.0 / count });

        var instruction: u32 = 0;

        if (horizontal) {

            try append_format(&self.shader_text, &used, "{d}: MUL TEMP[4], IN[0], CONST[0].zwzw\n", .{instruction});

        } else {

            try append_format(&self.shader_text, &used, "{d}: MOV TEMP[4], IN[0]\n", .{instruction});

        }

        instruction += 1;
        const axis = if (horizontal) "xxxx" else "yyyy";

        try append_format(&self.shader_text, &used, "{d}: MUL TEMP[1], CONST[0].{s}, IMM[0].xxxx\n", .{ instruction, axis });
        instruction += 1;
        try append_format(&self.shader_text, &used, "{d}: ADD TEMP[2], TEMP[4], TEMP[1]\n", .{instruction});
        instruction += 1;

        var offset: i32 = -radius_i32;

        while (offset <= radius_i32) : (offset += 1) {
            try append_format(&self.shader_text, &used, "{d}: TEX TEMP[3], TEMP[2], SAMP[0], 2D\n", .{instruction});
            instruction += 1;

            if (offset == -radius_i32) {

                try append_format(&self.shader_text, &used, "{d}: MOV TEMP[0], TEMP[3]\n", .{instruction});

            } else {

                try append_format(&self.shader_text, &used, "{d}: ADD TEMP[0], TEMP[0], TEMP[3]\n", .{instruction});

            }

            instruction += 1;

            if (offset != radius_i32) {

                try append_format(&self.shader_text, &used, "{d}: MAD TEMP[2], CONST[0].{s}, IMM[0].yyyy, TEMP[2]\n", .{ instruction, axis });
                instruction += 1;

            }

        }

        try append_format(&self.shader_text, &used, "{d}: MUL OUT[0], TEMP[0], IMM[0].zzzz\n", .{instruction});
        instruction += 1;
        try append_format(&self.shader_text, &used, "{d}: END\n", .{instruction});

        try self.create_shader(handle, shader_fragment, self.shader_text[0..used]);

    }

    fn acquire_workspace(self: *Renderer, scene: Rect, half_width: u32, half_height: u32, visible: Rect) !*Workspace {

        self.workspace_clock +%= 1;

        for (&self.workspaces) |*workspace| {

            if (!workspace.matches(scene, half_width, half_height, visible)) continue;

            workspace.last_used = self.workspace_clock;
            self.metrics.workspace_hits += 1;

            return workspace;

        }

        var selected: usize = 0;
        var oldest: u64 = std.math.maxInt(u64);

        for (&self.workspaces, 0..) |*workspace, index| {

            if (!workspace.valid) {

                selected = index;
                break;

            }

            if (workspace.last_used < oldest) {

                selected = index;
                oldest = workspace.last_used;

            }

        }

        const workspace = &self.workspaces[selected];

        self.release_workspace(workspace);

        const block = transient_object_base + @as(u32, @intCast(selected)) * workspace_handle_stride;

        workspace.surface_base = block;
        workspace.view_base = block + workspace_surface_count;
        workspace.scene_width = scene.width;
        workspace.scene_height = scene.height;
        workspace.half_width = half_width;
        workspace.half_height = half_height;
        workspace.visible_width = visible.width;
        workspace.visible_height = visible.height;
        workspace.frost_ready = false;
        workspace.last_used = self.workspace_clock;

        errdefer self.release_workspace(workspace);

        workspace.raw_scene = try self.create_texture(scene.width, scene.height, format_b8g8r8x8, bind_sampler_view, 4, target_texture_2d);
        workspace.frost_a = try self.create_texture(half_width, half_height, format_b8g8r8a8, bind_render_target | bind_sampler_view, 4, target_texture_2d);
        workspace.frost_b = try self.create_texture(half_width, half_height, format_b8g8r8a8, bind_render_target | bind_sampler_view, 4, target_texture_2d);
        workspace.material = try self.create_texture(visible.width, visible.height, format_b8g8r8a8, bind_sampler_view, 4, target_texture_2d);
        workspace.displacement = try self.create_texture(visible.width, visible.height, format_r8g8_snorm, bind_sampler_view, 2, target_texture_2d);
        workspace.output = try self.create_texture(visible.width, visible.height, format_b8g8r8a8, bind_render_target | bind_sampler_view, 4, target_texture_2d);

        self.stream.reset();

        try self.create_surface(workspace.surface_base, &workspace.frost_a);
        try self.create_surface(workspace.surface_base + 1, &workspace.frost_b);
        try self.create_surface(workspace.surface_base + 2, &workspace.output);
        try self.create_view(workspace.view_base, &workspace.raw_scene);
        try self.create_view(workspace.view_base + 1, &workspace.frost_a);
        try self.create_view(workspace.view_base + 2, &workspace.frost_b);
        try self.create_view(workspace.view_base + 3, &workspace.material);
        try self.create_view(workspace.view_base + 4, &workspace.displacement);
        try self.submit_stream();

        workspace.objects_ready = true;
        workspace.valid = true;

        return workspace;

    }

    fn release_workspace(self: *Renderer, workspace: *Workspace) void {

        if (workspace.objects_ready) self.destroy_objects(workspace.surface_base, workspace_surface_count, workspace.view_base, workspace_view_count);

        self.release_texture(&workspace.raw_scene);
        self.release_texture(&workspace.frost_a);
        self.release_texture(&workspace.frost_b);
        self.release_texture(&workspace.material);
        self.release_texture(&workspace.displacement);
        self.release_texture(&workspace.output);
        workspace.* = .{};

    }

    fn create_shader(self: *Renderer, handle: u32, shader_type: u32, text: []const u8) !void {

        const string_bytes = text.len + 1;
        const string_words = (string_bytes + 3) / 4;
        const total_words = 1 + 5 + string_words;

        if (total_words * 4 > self.control.len) return error.TooLarge;

        write_word(&self.shader_command, 0, ccmd_create_object | (object_shader << 8) | (@as(u32, @intCast(5 + string_words)) << 16));
        write_word(&self.shader_command, 1, handle);
        write_word(&self.shader_command, 2, shader_type);
        write_word(&self.shader_command, 3, @intCast(string_bytes));
        // This is the translation-token capacity, not the text byte length.
        // Leave headroom for the generated prominent-blur program.
        write_word(&self.shader_command, 4, 1200);
        write_word(&self.shader_command, 5, 0);

        const destination = self.shader_command[6 * 4 .. total_words * 4];

        @memset(destination, 0);
        @memcpy(destination[0..text.len], text);

        try self.submit_stream_bytes(self.shader_command[0 .. total_words * 4]);

    }

    fn create_texture(self: *Renderer, width: u32, height: u32, format: u32, bind: u32, bytes_per_pixel: u32, target: u32) !Texture {

        const bytes = std.math.mul(usize, @as(usize, width), @as(usize, height)) catch return error.TooLarge;
        const length = std.math.mul(usize, bytes, bytes_per_pixel) catch return error.TooLarge;
        var backing = try DmaBuffer.allocate(length);
        errdefer backing.release();

        const resource_id = self.next_resource_id;
        self.next_resource_id +%= 1;

        const request = ResourceCreate3d{

            .header = self.header(cmd_resource_create_3d, true),

            .resource_id = resource_id,
            .target = target,
            .format = format,
            .bind = bind,

            .width = width,
            .height = height,
            .depth = 1,
            .array_size = 1,

            .last_level = 0,
            .samples = 0,
            .flags = if (target == target_texture_2d) resource_y_0_top else 0,
            .padding = 0,

        };

        if (try self.control_struct(ResourceCreate3d, request, self.control[0..0]) != resp_ok_nodata) return error.Invalid;
        errdefer self.unref_resource(resource_id);

        const attach = AttachBacking{

            .header = self.header(0x0106, true),

            .resource_id = resource_id,
            .entry_count = 1,

            .address = backing.physical,
            .length = @intCast(length),
            .entry_padding = 0,

        };

        if (try self.control_struct(AttachBacking, attach, self.control[0..0]) != resp_ok_nodata) return error.Invalid;
        errdefer self.detach_backing(resource_id);

        const context_attach = ContextResource{

            .header = self.context_header(cmd_ctx_attach_resource, true),
            .resource_id = resource_id,
            .padding = 0,

        };

        if (try self.control_struct(ContextResource, context_attach, self.control[0..0]) != resp_ok_nodata) return error.Invalid;

        return .{

            .resource_id = resource_id,
            .width = width,
            .height = height,
            .format = format,
            .bytes_per_pixel = bytes_per_pixel,
            .backing = backing,

        };

    }

    fn release_texture(self: *Renderer, texture: *Texture) void {

        if (texture.resource_id == 0) return;

        const detach_context = ContextResource{

            .header = self.context_header(cmd_ctx_detach_resource, true),
            .resource_id = texture.resource_id,
            .padding = 0,

        };

        _ = self.control_struct(ContextResource, detach_context, self.control[0..0]) catch 0;

        self.detach_backing(texture.resource_id);
        self.unref_resource(texture.resource_id);
        texture.backing.release();
        texture.* = .{};

    }

    fn detach_backing(self: *Renderer, resource_id: u32) void {

        const request = ResourceUnref{

            .header = self.header(0x0107, true),
            .resource_id = resource_id,
            .padding = 0,

        };

        _ = self.control_struct(ResourceUnref, request, self.control[0..0]) catch 0;

    }

    fn unref_resource(self: *Renderer, resource_id: u32) void {

        const request = ResourceUnref{

            .header = self.header(0x0102, true),
            .resource_id = resource_id,
            .padding = 0,

        };

        _ = self.control_struct(ResourceUnref, request, self.control[0..0]) catch 0;

    }

    fn upload(self: *Renderer, texture: *const Texture) !void {

        barrier();

        const request = self.upload_request(texture);

        if (try self.control_struct(Transfer3d, request, self.control[0..0]) != resp_ok_nodata) return error.Invalid;

    }

    fn upload_many(self: *Renderer, textures: []const *const Texture) !void {

        if (textures.len == 0) return;
        if (textures.len > 4) return error.TooLarge;

        var transfers: [4]Transfer3d = undefined;
        var requests: [4]NodataRequest = undefined;

        for (textures, 0..) |texture, index| {

            transfers[index] = self.upload_request(texture);
            requests[index] = .{ .bytes = std.mem.asBytes(&transfers[index]) };

        }

        barrier();
        try self.transport.submit_nodata_batch(requests[0..textures.len]);

    }

    fn upload_request(self: *Renderer, texture: *const Texture) Transfer3d {

        return .{

            .header = self.context_header(cmd_transfer_to_host_3d, true),
            .box = .{

                .x = 0,
                .y = 0,
                .z = 0,

                .width = texture.width,
                .height = texture.height,
                .depth = 1,

            },

            .offset = 0,

            .resource_id = texture.resource_id,
            .level = 0,
            .stride = texture.width * texture.bytes_per_pixel,
            .layer_stride = texture.width * texture.height * texture.bytes_per_pixel,

        };

    }

    fn readback(self: *Renderer, texture: *const Texture) !void {

        const request = Transfer3d{

            .header = self.context_header(cmd_transfer_from_host_3d, true),
            .box = .{

                .x = 0,
                .y = 0,
                .z = 0,

                .width = texture.width,
                .height = texture.height,
                .depth = 1,

            },

            .offset = 0,

            .resource_id = texture.resource_id,
            .level = 0,
            .stride = texture.width * texture.bytes_per_pixel,
            .layer_stride = texture.width * texture.height * texture.bytes_per_pixel,

        };

        if (try self.control_struct(Transfer3d, request, self.control[0..0]) != resp_ok_nodata) return error.Invalid;

        barrier();

        self.metrics.readbacks += 1;

    }

    fn create_surface(self: *Renderer, handle: u32, texture: *const Texture) !void {

        try self.stream.command(ccmd_create_object, object_surface, 5);
        try self.stream.push(handle);
        try self.stream.push(texture.resource_id);
        try self.stream.push(texture.format);
        try self.stream.push(0);
        try self.stream.push(0);

    }

    fn create_view(self: *Renderer, handle: u32, texture: *const Texture) !void {

        try self.stream.command(ccmd_create_object, object_sampler_view, 6);
        try self.stream.push(handle);
        try self.stream.push(texture.resource_id);
        try self.stream.push(texture.format);
        try self.stream.push(0);
        try self.stream.push(0);
        try self.stream.push((1 << 3) | (2 << 6) | (3 << 9));

    }

    fn bind_object(self: *Renderer, object: u32, handle: u32) !void {

        try self.stream.command(ccmd_bind_object, object, 1);
        try self.stream.push(handle);

    }

    fn set_framebuffer(self: *Renderer, surface_handle: u32) !void {

        try self.stream.command(ccmd_set_framebuffer_state, 0, 3);
        try self.stream.push(1);
        try self.stream.push(0);
        try self.stream.push(surface_handle);

    }

    fn set_viewport(self: *Renderer, width: u32, height: u32) !void {

        const half_width = @as(f32, @floatFromInt(width)) / 2.0;
        const half_height = @as(f32, @floatFromInt(height)) / 2.0;

        try self.stream.command(ccmd_set_viewport_state, 0, 7);
        try self.stream.push(0);
        try self.stream.float(half_width);
        try self.stream.float(half_height);
        try self.stream.float(0.5);
        try self.stream.float(half_width);
        try self.stream.float(half_height);
        try self.stream.float(0.5);

    }

    fn clear(self: *Renderer, red: f32, green: f32, blue: f32, alpha: f32) !void {

        try self.stream.command(ccmd_clear, 0, 8);
        try self.stream.push(clear_color_0);
        try self.stream.float(red);
        try self.stream.float(green);
        try self.stream.float(blue);
        try self.stream.float(alpha);
        try self.stream.push(0);
        try self.stream.push(0);
        try self.stream.push(0);

    }

    fn draw(self: *Renderer, fragment_shader: u32, views: []const u32, constants: []const f32) !void {

        try self.stream.command(ccmd_set_sampler_views, 0, @intCast(2 + views.len));
        try self.stream.push(shader_fragment);
        try self.stream.push(0);

        for (views) |view| try self.stream.push(view);

        try self.stream.command(ccmd_bind_sampler_states, 0, @intCast(2 + views.len));
        try self.stream.push(shader_fragment);
        try self.stream.push(0);

        for (views) |_| try self.stream.push(sampler_handle);

        if (constants.len != 0) {

            try self.stream.command(ccmd_set_constant_buffer, 0, @intCast(2 + constants.len));
            try self.stream.push(shader_fragment);
            try self.stream.push(0);

            for (constants) |constant| try self.stream.float(constant);

        }

        try self.stream.command(ccmd_bind_shader, 0, 2);
        try self.stream.push(fragment_shader);
        try self.stream.push(shader_fragment);

        try self.stream.command(ccmd_link_shader, 0, 6);
        try self.stream.push(vertex_shader_handle);
        try self.stream.push(fragment_shader);
        try self.stream.push(0);
        try self.stream.push(0);
        try self.stream.push(0);
        try self.stream.push(0);

        try self.stream.command(ccmd_draw_vbo, 0, 12);
        try self.stream.push(0);
        try self.stream.push(3);
        try self.stream.push(primitive_triangles);

        for (0..8) |_| try self.stream.push(0);

        try self.stream.push(0);

    }

    fn destroy_objects(self: *Renderer, surface_base: u32, surface_count: usize, view_base: u32, view_count: usize) void {

        self.stream.reset();

        for (0..view_count) |index| {

            self.stream.command(ccmd_destroy_object, object_sampler_view, 1) catch return;
            self.stream.push(view_base + @as(u32, @intCast(index))) catch return;

        }

        for (0..surface_count) |index| {

            self.stream.command(ccmd_destroy_object, object_surface, 1) catch return;
            self.stream.push(surface_base + @as(u32, @intCast(index))) catch return;

        }

        self.submit_stream() catch {};

    }

    fn submit_stream(self: *Renderer) !void {

        try self.submit_stream_bytes(self.stream.bytes());

    }

    fn submit_stream_bytes(self: *Renderer, bytes: []const u8) !void {

        const header_bytes = @sizeOf(Submit3d);

        if (header_bytes + bytes.len > self.control.len) return error.TooLarge;

        const request = Submit3d{

            .header = self.context_header(cmd_submit_3d, true),
            .size = @intCast(bytes.len),
            .padding = 0,

        };

        @memcpy(self.control[0..header_bytes], std.mem.asBytes(&request));
        @memcpy(self.control[header_bytes .. header_bytes + bytes.len], bytes);

        var response: [@sizeOf(CtrlHeader)]u8 = undefined;
        const kind = try self.transport.submit(self.control[0 .. header_bytes + bytes.len], &response);

        try validate_fence(request.header, &response);

        if (kind != resp_ok_nodata) return error.Invalid;

        self.metrics.submissions += 1;

    }

    fn control_struct(self: *Renderer, comptime T: type, request: T, response: []u8) !u32 {

        var header_response: [@sizeOf(CtrlHeader)]u8 = undefined;
        const destination = if (response.len >= @sizeOf(CtrlHeader)) response else header_response[0..];
        const kind = try self.submit_struct(T, request, destination);
        const request_bytes = std.mem.asBytes(&request);
        const request_header = std.mem.bytesToValue(CtrlHeader, request_bytes[0..@sizeOf(CtrlHeader)]);

        try validate_fence(request_header, destination);

        return kind;

    }

    fn submit_struct(self: *Renderer, comptime T: type, request: T, response: []u8) !u32 {

        const bytes = std.mem.asBytes(&request);

        return self.transport.submit(bytes, response);

    }

    fn header(self: *Renderer, kind: u32, fenced: bool) CtrlHeader {

        const fence = if (fenced) self.take_fence() else 0;

        return .{

            .kind = kind,
            .flags = if (fenced) flag_fence else 0,

            .fence_id = fence,
            .ctx_id = 0,

            .ring_idx = 0,
            .padding = .{ 0, 0, 0 },

        };

    }

    fn context_header(self: *Renderer, kind: u32, fenced: bool) CtrlHeader {

        var result = self.header(kind, fenced);
        result.ctx_id = context_id;

        return result;

    }

    fn take_fence(self: *Renderer) u64 {

        const result = self.next_fence_id;
        self.next_fence_id +%= 1;

        return result;

    }

};

const vertex_shader =
    "VERT\n" ++
    "DCL IN[0]\n" ++
    "DCL IN[1]\n" ++
    "DCL OUT[0], POSITION\n" ++
    "DCL OUT[1], GENERIC[0]\n" ++
    "0: MOV OUT[1], IN[1]\n" ++
    "1: MOV OUT[0], IN[0]\n" ++
    "2: END\n";

const copy_shader =
    "FRAG\n" ++
    "DCL IN[0], GENERIC[0], LINEAR\n" ++
    "DCL OUT[0], COLOR\n" ++
    "DCL SAMP[0]\n" ++
    "DCL SVIEW[0], 2D, FLOAT\n" ++
    "DCL TEMP[0]\n" ++
    "0: TEX TEMP[0], IN[0], SAMP[0], 2D\n" ++
    "1: MOV OUT[0], TEMP[0]\n" ++
    "2: END\n";

const resolve_shader =
    "FRAG\n" ++
    "DCL IN[0], GENERIC[0], LINEAR\n" ++
    "DCL OUT[0], COLOR\n" ++
    "DCL CONST[0..5]\n" ++
    "DCL SAMP[0]\n" ++
    "DCL SAMP[1]\n" ++
    "DCL SAMP[2]\n" ++
    "DCL SAMP[3]\n" ++
    "DCL SVIEW[0], 2D, FLOAT\n" ++
    "DCL SVIEW[1], 2D, FLOAT\n" ++
    "DCL SVIEW[2], 2D, FLOAT\n" ++
    "DCL SVIEW[3], 2D, FLOAT\n" ++
    "DCL TEMP[0..9]\n" ++
    "IMM[0] FLT32 {0.0, 1.0, 0.5, -1.0}\n" ++
    "0: TEX TEMP[0], IN[0], SAMP[2], 2D\n" ++
    "1: TEX TEMP[1], IN[0], SAMP[3], 2D\n" ++
    "2: MAD TEMP[2].xy, IN[0], CONST[0], CONST[0].zwzw\n" ++
    "3: MUL TEMP[3].xy, TEMP[1], CONST[1]\n" ++
    "4: ADD TEMP[3].xy, TEMP[2], TEMP[3]\n" ++
    "5: MAD TEMP[4].xy, IN[0], CONST[4], CONST[4].zwzw\n" ++
    "6: MUL TEMP[9].xy, TEMP[1], CONST[5]\n" ++
    "7: ADD TEMP[4].xy, TEMP[4], TEMP[9]\n" ++
    "8: TEX TEMP[6], TEMP[4], SAMP[1], 2D\n" ++
    "9: TEX TEMP[7], TEMP[3], SAMP[0], 2D\n" ++
    "10: MUL TEMP[8].xy, TEMP[1], TEMP[1]\n" ++
    "11: ADD TEMP[8].z, TEMP[8].xxxx, TEMP[8].yyyy\n" ++
    "12: MUL TEMP[8].x, TEMP[8].zzzz, CONST[3].xxxx\n" ++
    "13: MUL TEMP[9].xy, TEMP[1], CONST[2]\n" ++
    "14: MAD TEMP[2].xy, TEMP[9], IMM[0].wwww, TEMP[3]\n" ++
    "15: ADD TEMP[4].xy, TEMP[3], TEMP[9]\n" ++
    "16: TEX TEMP[5], TEMP[2], SAMP[0], 2D\n" ++
    "17: TEX TEMP[2], TEMP[4], SAMP[0], 2D\n" ++
    "18: MOV TEMP[4], TEMP[7]\n" ++
    "19: MOV TEMP[4].x, TEMP[5].xxxx\n" ++
    "20: MOV TEMP[4].z, TEMP[2].zzzz\n" ++
    "21: MAD TEMP[8].y, TEMP[8].xxxx, IMM[0].wwww, IMM[0].yyyy\n" ++
    "22: MUL TEMP[4], TEMP[4], TEMP[8].xxxx\n" ++
    "23: MAD TEMP[7], TEMP[7], TEMP[8].yyyy, TEMP[4]\n" ++
    "24: MUL TEMP[7], TEMP[7], TEMP[8].xxxx\n" ++
    "25: MAD TEMP[6], TEMP[6], TEMP[8].yyyy, TEMP[7]\n" ++
    "26: MAD TEMP[8].z, TEMP[0].wwww, IMM[0].wwww, IMM[0].yyyy\n" ++
    "27: MAD TEMP[6].xyz, TEMP[6], TEMP[8].zzzz, TEMP[0]\n" ++
    "28: MOV TEMP[6].w, IMM[0].yyyy\n" ++
    "29: MOV OUT[0], TEMP[6]\n" ++
    "30: END\n";

fn capture_backdrop(texture: *const Texture, back: [*]const u32, stride: u32, rect: Rect) void {

    const destination: [*]u32 = @ptrFromInt(texture.backing.base);
    var y: u32 = 0;

    while (y < rect.height) : (y += 1) {

        const source_start = @as(usize, rect.y + y) * stride + rect.x;
        const destination_start = @as(usize, y) * rect.width;

        @memcpy(destination[destination_start .. destination_start + rect.width], back[source_start .. source_start + rect.width]);

    }

}

fn capture_material(
    material: *const Texture,
    displacement: *const Texture,
    foreground: [*]const u32,
    effect: [*]const u8,
    surface_width: u32,
    source_x: u32,
    source_y: u32,
    width: u32,
    height: u32,
) void {

    const material_pixels: [*]u32 = @ptrFromInt(material.backing.base);
    const displacement_bytes: [*]u8 = @ptrFromInt(displacement.backing.base);
    var y: u32 = 0;

    while (y < height) : (y += 1) {

        var x: u32 = 0;

        while (x < width) : (x += 1) {

            const source_index = @as(usize, source_y + y) * surface_width + source_x + x;
            const destination_index = @as(usize, y) * width + x;
            const encoded = foreground[source_index];
            const encoded_alpha: u8 = @truncate(encoded >> 24);
            const alpha: u32 = if (encoded_alpha == 0) 255 else encoded_alpha - 1;

            material_pixels[destination_index] = (encoded & 0x00ff_ffff) | (alpha << 24);
            displacement_bytes[destination_index * 2] = effect[source_index * 2];
            displacement_bytes[destination_index * 2 + 1] = effect[source_index * 2 + 1];

        }

    }

}

fn build_header_material(
    foreground: [*]u32,
    effect: [*]u8,
    width: u32,
    height: u32,
    source_x: u32,
    source_y: u32,
    header_width: u32,
    header_height: u32,
    tint: u32,
    opacity: u8,
    radius: u8,
    joined: bool,
) void {

    const requested_radius: i32 = @intCast(radius);
    const bounds = draw.Rect{ .x = 0, .y = 0, .w = @intCast(header_width), .h = @intCast(header_height) };
    const rounded_radius = draw.round.clamp_radius(bounds, requested_radius);
    const masks = draw.round.masks_for(rounded_radius);
    const refraction = lib.quartz.safe_refraction(64, 12);
    var y: u32 = 0;

    while (y < height) : (y += 1) {

        const local_y: i32 = @intCast(source_y + y);
        var x: u32 = 0;

        while (x < width) : (x += 1) {

            const local_x: i32 = @intCast(source_x + x);
            const index = @as(usize, y) * @as(usize, width) + @as(usize, x);
            const coverage = header_coverage(header_width, local_x, local_y, rounded_radius, masks);
            const alpha: u8 = @intCast((@as(u32, opacity) * coverage + 127) / 255);
            const displacement_x = attenuate_header_displacement(header_axis(local_x, @intCast(header_width), refraction), coverage);
            var displacement_y = -header_component(local_y, refraction);
            const bottom = @as(i32, @intCast(header_height)) - 1 - local_y;

            if (!joined) displacement_y += header_component(bottom, refraction);

            displacement_y = attenuate_header_displacement(displacement_y, coverage);
            foreground[index] = draw.with_alpha(tint, alpha);
            effect[index * 2] = @bitCast(@as(i8, @intCast(@max(-127, @min(displacement_x, 127)))));
            effect[index * 2 + 1] = @bitCast(@as(i8, @intCast(@max(-127, @min(displacement_y, 127)))));

        }

    }

}

fn header_coverage(width: u32, x: i32, y: i32, radius: i32, masks: ?draw.round.Masks) u8 {

    if (radius <= 1 or y >= radius) return 255;

    const width_i32: i32 = @intCast(width);

    if (x >= radius and x < width_i32 - radius) return 255;

    const available = masks orelse return 255;
    const row = @as(usize, @intCast(y)) * @as(usize, @intCast(radius));

    if (x < radius) return available.tl[row + @as(usize, @intCast(x))];

    return available.tr[row + @as(usize, @intCast(x - (width_i32 - radius)))];

}

fn header_axis(position: i32, extent: i32, refraction: i32) i32 {

    const opposite = extent - 1 - position;

    return -header_component(position, refraction) + header_component(opposite, refraction);

}

fn header_component(distance: i32, refraction: i32) i32 {

    const bezel: i32 = 12;

    if (distance < 0 or distance >= bezel) return 0;

    const profile = lib.quartz.lens_profile(bezel - distance, bezel);

    return @divTrunc(@as(i32, profile) * refraction + 127, 255);

}

fn attenuate_header_displacement(displacement: i32, coverage: u8) i32 {

    if (coverage == 255) return displacement;

    return @divTrunc(displacement * @as(i32, coverage), 255);

}

fn copy_output(back: [*]u32, stride: u32, rect: Rect, texture: *const Texture) void {

    const source: [*]const u32 = @ptrFromInt(texture.backing.base);
    var y: u32 = 0;

    while (y < rect.height) : (y += 1) {

        const source_start = @as(usize, y) * rect.width;
        const destination_start = @as(usize, rect.y + y) * stride + rect.x;

        @memcpy(back[destination_start .. destination_start + rect.width], source[source_start .. source_start + rect.width]);

    }

}

fn expand(rect: Rect, halo: u32, width: u32, height: u32) Rect {

    const x = rect.x -| halo;
    const y = rect.y -| halo;
    const right = @min(width, rect.x + rect.width + halo);
    const bottom = @min(height, rect.y + rect.height + halo);

    return .{

        .x = x,
        .y = y,
        .width = right - x,
        .height = bottom - y,

    };

}

fn damage_halo(density: u8) u32 {

    return max_refraction_pixels + chroma_radius + frost_scale * frost_radius(density) + 1;

}

fn frost_radius(density: u8) u32 {

    return switch (density) {

        1 => frost_radius_light,
        3 => frost_radius_prominent,
        else => frost_radius_regular,

    };

}

const BlurHandles = struct {

    horizontal: u32,
    vertical: u32,

};

fn blur_shader_handles(radius: u32) BlurHandles {

    return switch (radius) {

        frost_radius_light => .{ .horizontal = blur_h_light_handle, .vertical = blur_v_light_handle },
        frost_radius_prominent => .{ .horizontal = blur_h_prominent_handle, .vertical = blur_v_prominent_handle },
        else => .{ .horizontal = blur_h_regular_handle, .vertical = blur_v_regular_handle },

    };

}

fn format_supported(mask: []const u8, format: u32) bool {

    const word_index: usize = @intCast(format / 32);

    if (word_index >= mask.len / 4) return false;

    const offset = word_index * 4;
    const word = std.mem.readInt(u32, mask[offset..][0..4], .little);

    return word & (@as(u32, 1) << @intCast(format % 32)) != 0;

}

fn write_word(buffer: []u8, index: usize, value: u32) void {

    const offset = index * @sizeOf(u32);

    std.mem.writeInt(u32, buffer[offset..][0..@sizeOf(u32)], value, .little);

}

fn validate_fence(request: CtrlHeader, response: []const u8) !void {

    if (request.flags & flag_fence == 0) return;
    if (response.len < @sizeOf(CtrlHeader)) return error.Invalid;

    const response_header = std.mem.bytesToValue(CtrlHeader, response[0..@sizeOf(CtrlHeader)]);

    if (response_header.flags & flag_fence == 0) return error.Invalid;
    if (response_header.fence_id != request.fence_id) return error.Invalid;

}

fn append_text(buffer: []u8, used: *usize, text: []const u8) !void {

    if (used.* + text.len > buffer.len) return error.TooLarge;

    @memcpy(buffer[used.* .. used.* + text.len], text);
    used.* += text.len;

}

fn append_format(buffer: []u8, used: *usize, comptime format: []const u8, arguments: anytype) !void {

    const written = try std.fmt.bufPrint(buffer[used.*..], format, arguments);
    used.* += written.len;

}

fn zero_header() CtrlHeader {

    return .{

        .kind = 0,
        .flags = 0,

        .fence_id = 0,
        .ctx_id = 0,

        .ring_idx = 0,
        .padding = .{ 0, 0, 0 },

    };

}

fn barrier() void {

    asm volatile ("dsb sy" ::: .{ .memory = true });

}
