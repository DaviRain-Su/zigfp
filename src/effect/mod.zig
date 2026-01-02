//! 效果系统模块
//!
//! 提供各种效果抽象：
//! - Effect - 代数效果
//! - IO - IO 操作
//! - FileSystem - 文件系统
//! - Random - 随机数
//! - Time - 时间
//! - Config - 配置

const std = @import("std");

pub const effect = @import("effect.zig");
pub const io = @import("io.zig");
pub const file_system = @import("file_system.zig");
pub const random = @import("random.zig");
pub const time = @import("time.zig");
pub const config = @import("config.zig");

// ============ Effect ============
pub const Effect = effect.Effect;
pub const EffectTag = effect.EffectTag;
pub const Handler = effect.Handler;
pub const ReaderEffect = effect.ReaderEffect;
pub const StateEffect = effect.StateEffect;
pub const ErrorEffect = effect.ErrorEffect;
pub const LogEffect = effect.LogEffect;
pub const runPure = effect.runPure;

// ============ IO ============
pub const IO = io.IO;
pub const IOVoid = io.IOVoid;
pub const Console = io.Console;
pub const console = io.console;
pub const putStrLn = io.putStrLn;
pub const putStr = io.putStr;
pub const getLine = io.getLine;
pub const getContents = io.getContents;

// ============ FileSystem ============
pub const FileSystemEffect = file_system.FileSystemEffect;
pub const FileSystemHandler = file_system.FileSystemHandler;
pub const readFile = file_system.readFile;
pub const writeFile = file_system.writeFile;
pub const fileExists = file_system.fileExists;

// ============ Random ============
pub const RandomOp = random.RandomOp;
pub const RandomEffect = random.RandomEffect;
pub const RandomResult = random.RandomResult;
pub const RandomHandler = random.RandomHandler;
pub const randomInt = random.randomInt;
pub const randomUint = random.randomUint;
pub const randomFloat = random.randomFloat;
pub const randomFloatRange = random.randomFloatRange;
pub const randomBytes = random.randomBytes;
pub const randomBool = random.randomBool;
pub const randomChoice = random.randomChoice;
pub const shuffleRandom = random.shuffle;
pub const sampleRandom = random.sample;

// ============ Time ============
pub const TimeOp = time.TimeOp;
pub const TimeEffect = time.TimeEffect;
pub const TimeResult = time.TimeResult;
pub const TimeFormat = time.TimeFormat;
pub const DateTime = time.DateTime;
pub const Duration = time.Duration;
pub const TimeHandler = time.TimeHandler;
pub const MockTimeHandler = time.MockTimeHandler;
pub const currentTime = time.currentTime;
pub const currentTimeMillis = time.currentTimeMillis;
pub const monotonicTime = time.monotonicTime;
pub const sleepNs = time.sleepNs;
pub const sleepMs = time.sleepMs;
pub const sleepDuration = time.sleep;
pub const formatTime = time.formatTime;
pub const parseTime = time.parseTime;
pub const measureTime = time.measure;

// ============ Config ============
pub const ConfigOp = config.ConfigOp;
pub const ConfigEffect = config.ConfigEffect;
pub const ConfigResult = config.ConfigResult;
pub const ConfigValue = config.ConfigValue;
pub const ConfigFormat = config.ConfigFormat;
pub const ConfigHandler = config.ConfigHandler;
pub const EnvConfigHandler = config.EnvConfigHandler;
pub const getConfig = config.getConfig;
pub const setConfig = config.setConfig;
pub const deleteConfig = config.deleteConfig;
pub const hasConfig = config.hasConfig;
pub const configKeys = config.configKeys;
pub const loadConfig = config.loadConfig;
pub const saveConfig = config.saveConfig;
pub const clearConfig = config.clearConfig;
pub const getConfigOrDefault = config.getConfigOrDefault;

test {
    std.testing.refAllDecls(@This());
}
