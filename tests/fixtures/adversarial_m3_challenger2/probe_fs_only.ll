target datalayout = "e-m:e-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"
target triple = "x86_64-unknown-linux-gnu"
!llvm.module.flags = !{!0, !1, !12}
!0 = !{i32 1, !"wchar_size", i32 4}
!1 = !{i32 8, !"PIC Level", i32 2}
declare void @llvm.lifetime.start.p0(i64 immarg, ptr nocapture) nounwind
declare void @llvm.lifetime.end.p0(i64 immarg, ptr nocapture) nounwind
declare void @llvm.assume(i1) nounwind willreturn memory(inaccessiblemem: readwrite)
!llvm.dbg.cu = !{!10}
!10 = distinct !DICompileUnit(language: DW_LANG_C99, file: !11, producer: "oodac", isOptimized: false, runtimeVersion: 0, emissionKind: LineTablesOnly, splitDebugInlining: false)
!11 = !DIFile(filename: "oodac/tests/fixtures/adversarial_m3_challenger2/probe_fs_only.oo", directory: ".")
!12 = !{i32 2, !"Debug Info Version", i32 3}
!13 = !DISubroutineType(types: !14)
!14 = !{null}
%OoStr = type { ptr, i64 }
%OoSList = type { ptr, i64, i64 }
%OoIList = type { ptr, i64, i64 }
%OoResI = type { i32, i64, %OoStr }
%OoResL = type { i32, %OoSList, %OoStr }
%OoResLI = type { i32, %OoIList, %OoStr }
%OoResS = type { i32, %OoStr }
%OoOptI = type { i32, i64 }
%OoOptS = type { i32, %OoStr }
%OoResV = type { i32, %OoStr }
%OoClosure = type { ptr, ptr, ptr }
declare i32 @oo_path_exists(i64, { ptr, i64 }) nounwind
declare i64 @oo_file_size(i64, { ptr, i64 }) nounwind
declare { ptr, i64 } @oo_str_lit(ptr) nounwind
declare void @oo_str_retain({ ptr, i64 }) nounwind
declare void @oo_str_release({ ptr, i64 }) nounwind
declare i64 @oo_cap_grant_fsread() nounwind
!21 = distinct !DISubprogram(name: "check_fs", scope: !11, file: !11, line: 1, type: !13, spFlags: DISPFlagDefinition, unit: !10)
; FN check_fs
define hidden noundef i64 @check_fs(i64 noundef %p_fs, { ptr, i64 } %p_path) nounwind !dbg !21 {
  %v_fs = alloca i64, align 8
  %v_path = alloca %OoStr, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_fs), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.start.p0(i64 16, ptr %v_path), !dbg !DILocation(line: 1, column: 1, scope: !21)
  store i64 %p_fs, ptr %v_fs, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  store { ptr, i64 } %p_path, ptr %v_path, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t3 = load i64, ptr %v_fs, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t4 = load { ptr, i64 }, ptr %v_path, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t5 = call i32 @oo_path_exists(i64 %t3, { ptr, i64 } %t4), !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t6 = icmp ne i32 %t5, 0, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t8 = zext i1 %t6 to i64, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t9 = icmp ne i64 %t8, 0, !dbg !DILocation(line: 1, column: 1, scope: !21)
  br i1 %t9, label %then9, label %else9, !dbg !DILocation(line: 1, column: 1, scope: !21)
then9:
  %t10 = load i64, ptr %v_fs, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t11 = load { ptr, i64 }, ptr %v_path, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t12 = call i64 @oo_file_size(i64 %t10, { ptr, i64 } %t11), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_fs), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 16, ptr %v_path), !dbg !DILocation(line: 1, column: 1, scope: !21)
  ret i64 %t12, !dbg !DILocation(line: 1, column: 1, scope: !21)
else9:
  br label %end9, !dbg !DILocation(line: 1, column: 1, scope: !21)
end9:
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_fs), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 16, ptr %v_path), !dbg !DILocation(line: 1, column: 1, scope: !21)
  ret i64 0, !dbg !DILocation(line: 1, column: 1, scope: !21)
}
!60 = distinct !DISubprogram(name: "main", scope: !11, file: !11, line: 40, type: !13, spFlags: DISPFlagDefinition, unit: !10)
; FN main
@.s61 = private unnamed_addr constant [9 x i8] c"test.txt\00"
define hidden i32 @main(i32 noundef %argc, ptr nocapture noundef %argv) nounwind !dbg !60 {
entry:
  %v_fs = alloca i64, align 8
  %a14 = alloca %OoStr, align 8
  %v_sz_s53 = alloca i64, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_fs), !dbg !DILocation(line: 1, column: 1, scope: !60)
  call void @llvm.lifetime.start.p0(i64 16, ptr %a14), !dbg !DILocation(line: 1, column: 1, scope: !60)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_sz_s53), !dbg !DILocation(line: 1, column: 1, scope: !60)
  %g_fs = call i64 @oo_cap_grant_fsread(), !dbg !DILocation(line: 1, column: 1, scope: !60)
  store i64 %g_fs, ptr %v_fs, align 8, !dbg !DILocation(line: 1, column: 1, scope: !60)
  %t11 = load i64, ptr %v_fs, align 8, !dbg !DILocation(line: 1, column: 1, scope: !60)
  %t12 = getelementptr inbounds [9 x i8], ptr @.s61, i64 0, i64 0, !dbg !DILocation(line: 1, column: 1, scope: !60)
  %t13 = call { ptr, i64 } @oo_str_lit(ptr %t12), !dbg !DILocation(line: 1, column: 1, scope: !60)
  store { ptr, i64 } %t13, ptr %a14, align 8, !dbg !DILocation(line: 1, column: 1, scope: !60)
  %t15 = load { ptr, i64 }, ptr %a14, align 8, !dbg !DILocation(line: 1, column: 1, scope: !60)
  %t16 = call i64 @check_fs(i64 %t11, { ptr, i64 } %t15), !dbg !DILocation(line: 1, column: 1, scope: !60)
  store i64 %t16, ptr %v_sz_s53, align 8, !dbg !DILocation(line: 1, column: 1, scope: !60)
  %t17 = load i64, ptr %v_sz_s53, align 8, !dbg !DILocation(line: 1, column: 1, scope: !60)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_fs), !dbg !DILocation(line: 1, column: 1, scope: !60)
  call void @llvm.lifetime.end.p0(i64 16, ptr %a14), !dbg !DILocation(line: 1, column: 1, scope: !60)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_sz_s53), !dbg !DILocation(line: 1, column: 1, scope: !60)
  ret i32 0, !dbg !DILocation(line: 1, column: 1, scope: !60)
}
