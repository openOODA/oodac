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
!11 = !DIFile(filename: "oodac/tests/fixtures/adversarial_m3_challenger2/probe_contract_assume.oo", directory: ".")
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
declare ptr @getenv(ptr) nounwind
@.oodatest = private unnamed_addr constant [10 x i8] c"OODA_TEST\00"
@.vok = private unnamed_addr constant [10 x i8] c"OK verify\00"
declare void @oo_print_str(ptr, i64) nounwind
declare void @oo_println() nounwind
declare { ptr, i64 } @oo_str_lit(ptr) nounwind
declare void @oo_process_exit(i64) noreturn nounwind
@.con_1000_inc = private unnamed_addr constant [22 x i8] c"ERR\09contract\09ensures\0A\00"
!21 = distinct !DISubprogram(name: "inc", scope: !11, file: !11, line: 1, type: !13, spFlags: DISPFlagDefinition, unit: !10)
; FN inc
define hidden noundef i64 @inc(i64 noundef %p_x) readonly nounwind !dbg !21 {
  %v_x = alloca i64, align 8
  %cres18 = alloca i64, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_x), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.start.p0(i64 8, ptr %cres18), !dbg !DILocation(line: 1, column: 1, scope: !21)
  store i64 %p_x, ptr %v_x, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t3 = load i64, ptr %v_x, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t5 = add nsw i64 %t3, 1, !dbg !DILocation(line: 1, column: 1, scope: !21)
  store i64 %t5, ptr %cres18, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t6 = load i64, ptr %cres18, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t7 = load i64, ptr %v_x, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t9 = add nsw i64 %t7, 1, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t10 = icmp eq i64 %t6, %t9, !dbg !DILocation(line: 1, column: 1, scope: !21)
  br i1 %t10, label %ctok1000_inc, label %ctrap1000_inc, !dbg !DILocation(line: 1, column: 1, scope: !21)
ctrap1000_inc:
  %t11 = getelementptr inbounds [22 x i8], ptr @.con_1000_inc, i64 0, i64 0, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t12 = call { ptr, i64 } @oo_str_lit(ptr %t11), !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t13 = extractvalue { ptr, i64 } %t12, 0, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t14 = extractvalue { ptr, i64 } %t12, 1, !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @oo_print_str(ptr %t13, i64 %t14), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @oo_println(), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @oo_process_exit(i64 1), !dbg !DILocation(line: 1, column: 1, scope: !21)
  unreachable, !dbg !DILocation(line: 1, column: 1, scope: !21)
ctok1000_inc:
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_x), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 8, ptr %cres18), !dbg !DILocation(line: 1, column: 1, scope: !21)
  ret i64 %t5, !dbg !DILocation(line: 1, column: 1, scope: !21)
}
!44 = distinct !DISubprogram(name: "main", scope: !11, file: !11, line: 24, type: !13, spFlags: DISPFlagDefinition, unit: !10)
; FN main
define hidden i32 @main(i32 noundef %argc, ptr nocapture noundef %argv) nounwind !dbg !44 {
entry:
  %v_r_s33 = alloca i64, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_r_s33), !dbg !DILocation(line: 1, column: 1, scope: !44)
  %t12 = call i64 @inc(i64 5), !dbg !DILocation(line: 1, column: 1, scope: !44)
  store i64 %t12, ptr %v_r_s33, align 8, !dbg !DILocation(line: 1, column: 1, scope: !44)
  %t13 = load i64, ptr %v_r_s33, align 8, !dbg !DILocation(line: 1, column: 1, scope: !44)
  %t15 = icmp eq i64 %t13, 6, !dbg !DILocation(line: 1, column: 1, scope: !44)
  br i1 %t15, label %then15, label %else15, !dbg !DILocation(line: 1, column: 1, scope: !44)
then15:
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_r_s33), !dbg !DILocation(line: 1, column: 1, scope: !44)
  ret i32 0, !dbg !DILocation(line: 1, column: 1, scope: !44)
else15:
  br label %end15, !dbg !DILocation(line: 1, column: 1, scope: !44)
end15:
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_r_s33), !dbg !DILocation(line: 1, column: 1, scope: !44)
  ret i32 0, !dbg !DILocation(line: 1, column: 1, scope: !44)
}
