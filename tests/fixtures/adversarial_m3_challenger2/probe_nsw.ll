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
!11 = !DIFile(filename: "oodac/tests/fixtures/adversarial_m3_challenger2/probe_nsw.oo", directory: ".")
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
declare void @oo_println() nounwind
declare void @oo_print_int(i64) nounwind
!21 = distinct !DISubprogram(name: "signed_i64_ops", scope: !11, file: !11, line: 1, type: !13, spFlags: DISPFlagDefinition, unit: !10)
; FN signed_i64_ops
define hidden noundef i64 @signed_i64_ops(i64 noundef %p_a, i64 noundef %p_b) readonly nounwind !dbg !21 {
  %v_a = alloca i64, align 8
  %v_b = alloca i64, align 8
  %v_s_s17 = alloca i64, align 8
  %v_d_s26 = alloca i64, align 8
  %v_p_s35 = alloca i64, align 8
  %v_neg_s44 = alloca i64, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_a), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_b), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_s_s17), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_d_s26), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_p_s35), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_neg_s44), !dbg !DILocation(line: 1, column: 1, scope: !21)
  store i64 %p_a, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  store i64 %p_b, ptr %v_b, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t3 = load i64, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t4 = load i64, ptr %v_b, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t5 = add nsw i64 %t3, %t4, !dbg !DILocation(line: 1, column: 1, scope: !21)
  store i64 %t5, ptr %v_s_s17, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t6 = load i64, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t7 = load i64, ptr %v_b, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t8 = sub nsw i64 %t6, %t7, !dbg !DILocation(line: 1, column: 1, scope: !21)
  store i64 %t8, ptr %v_d_s26, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t9 = load i64, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t10 = load i64, ptr %v_b, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t11 = mul nsw i64 %t9, %t10, !dbg !DILocation(line: 1, column: 1, scope: !21)
  store i64 %t11, ptr %v_p_s35, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t12 = load i64, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t13 = sub nsw i64 0, %t12, !dbg !DILocation(line: 1, column: 1, scope: !21)
  store i64 %t13, ptr %v_neg_s44, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t14 = load i64, ptr %v_s_s17, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t15 = load i64, ptr %v_d_s26, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t16 = add nsw i64 %t14, %t15, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t17 = load i64, ptr %v_p_s35, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t18 = add nsw i64 %t16, %t17, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t19 = load i64, ptr %v_neg_s44, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t20 = add nsw i64 %t18, %t19, !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_a), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_b), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_s_s17), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_d_s26), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_p_s35), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_neg_s44), !dbg !DILocation(line: 1, column: 1, scope: !21)
  ret i64 %t20, !dbg !DILocation(line: 1, column: 1, scope: !21)
}
!81 = distinct !DISubprogram(name: "unsigned_u64_ops", scope: !11, file: !11, line: 61, type: !13, spFlags: DISPFlagDefinition, unit: !10)
; FN unsigned_u64_ops
define hidden noundef i64 @unsigned_u64_ops(i64 noundef %p_a, i64 noundef %p_b) readonly nounwind !dbg !81 {
  %v_a = alloca i64, align 8
  %v_b = alloca i64, align 8
  %v_s_s77 = alloca i64, align 8
  %v_d_s86 = alloca i64, align 8
  %v_p_s95 = alloca i64, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_a), !dbg !DILocation(line: 1, column: 1, scope: !81)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_b), !dbg !DILocation(line: 1, column: 1, scope: !81)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_s_s77), !dbg !DILocation(line: 1, column: 1, scope: !81)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_d_s86), !dbg !DILocation(line: 1, column: 1, scope: !81)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_p_s95), !dbg !DILocation(line: 1, column: 1, scope: !81)
  store i64 %p_a, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !81)
  store i64 %p_b, ptr %v_b, align 8, !dbg !DILocation(line: 1, column: 1, scope: !81)
  %t3 = load i64, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !81)
  %t4 = load i64, ptr %v_b, align 8, !dbg !DILocation(line: 1, column: 1, scope: !81)
  %t5 = add i64 %t3, %t4, !dbg !DILocation(line: 1, column: 1, scope: !81)
  store i64 %t5, ptr %v_s_s77, align 8, !dbg !DILocation(line: 1, column: 1, scope: !81)
  %t6 = load i64, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !81)
  %t7 = load i64, ptr %v_b, align 8, !dbg !DILocation(line: 1, column: 1, scope: !81)
  %t8 = sub i64 %t6, %t7, !dbg !DILocation(line: 1, column: 1, scope: !81)
  store i64 %t8, ptr %v_d_s86, align 8, !dbg !DILocation(line: 1, column: 1, scope: !81)
  %t9 = load i64, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !81)
  %t10 = load i64, ptr %v_b, align 8, !dbg !DILocation(line: 1, column: 1, scope: !81)
  %t11 = mul i64 %t9, %t10, !dbg !DILocation(line: 1, column: 1, scope: !81)
  store i64 %t11, ptr %v_p_s95, align 8, !dbg !DILocation(line: 1, column: 1, scope: !81)
  %t12 = load i64, ptr %v_s_s77, align 8, !dbg !DILocation(line: 1, column: 1, scope: !81)
  %t13 = load i64, ptr %v_d_s86, align 8, !dbg !DILocation(line: 1, column: 1, scope: !81)
  %t14 = add i64 %t12, %t13, !dbg !DILocation(line: 1, column: 1, scope: !81)
  %t15 = load i64, ptr %v_p_s95, align 8, !dbg !DILocation(line: 1, column: 1, scope: !81)
  %t16 = add i64 %t14, %t15, !dbg !DILocation(line: 1, column: 1, scope: !81)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_a), !dbg !DILocation(line: 1, column: 1, scope: !81)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_b), !dbg !DILocation(line: 1, column: 1, scope: !81)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_s_s77), !dbg !DILocation(line: 1, column: 1, scope: !81)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_d_s86), !dbg !DILocation(line: 1, column: 1, scope: !81)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_p_s95), !dbg !DILocation(line: 1, column: 1, scope: !81)
  ret i64 %t16, !dbg !DILocation(line: 1, column: 1, scope: !81)
}
!131 = distinct !DISubprogram(name: "signed_i32_ops", scope: !11, file: !11, line: 111, type: !13, spFlags: DISPFlagDefinition, unit: !10)
; FN signed_i32_ops
define hidden noundef i32 @signed_i32_ops(i32 noundef %p_a, i32 noundef %p_b) readonly nounwind !dbg !131 {
  %v_a = alloca i32, align 8
  %v_b = alloca i32, align 8
  %v_s_s127 = alloca i32, align 8
  %v_d_s136 = alloca i32, align 8
  %v_p_s145 = alloca i32, align 8
  %v_neg_s154 = alloca i32, align 8
  call void @llvm.lifetime.start.p0(i64 4, ptr %v_a), !dbg !DILocation(line: 1, column: 1, scope: !131)
  call void @llvm.lifetime.start.p0(i64 4, ptr %v_b), !dbg !DILocation(line: 1, column: 1, scope: !131)
  call void @llvm.lifetime.start.p0(i64 4, ptr %v_s_s127), !dbg !DILocation(line: 1, column: 1, scope: !131)
  call void @llvm.lifetime.start.p0(i64 4, ptr %v_d_s136), !dbg !DILocation(line: 1, column: 1, scope: !131)
  call void @llvm.lifetime.start.p0(i64 4, ptr %v_p_s145), !dbg !DILocation(line: 1, column: 1, scope: !131)
  call void @llvm.lifetime.start.p0(i64 4, ptr %v_neg_s154), !dbg !DILocation(line: 1, column: 1, scope: !131)
  store i32 %p_a, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !131)
  store i32 %p_b, ptr %v_b, align 8, !dbg !DILocation(line: 1, column: 1, scope: !131)
  %t3 = load i32, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !131)
  %t4 = load i32, ptr %v_b, align 8, !dbg !DILocation(line: 1, column: 1, scope: !131)
  %t5 = add nsw i32 %t3, %t4, !dbg !DILocation(line: 1, column: 1, scope: !131)
  store i32 %t5, ptr %v_s_s127, align 8, !dbg !DILocation(line: 1, column: 1, scope: !131)
  %t6 = load i32, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !131)
  %t7 = load i32, ptr %v_b, align 8, !dbg !DILocation(line: 1, column: 1, scope: !131)
  %t8 = sub nsw i32 %t6, %t7, !dbg !DILocation(line: 1, column: 1, scope: !131)
  store i32 %t8, ptr %v_d_s136, align 8, !dbg !DILocation(line: 1, column: 1, scope: !131)
  %t9 = load i32, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !131)
  %t10 = load i32, ptr %v_b, align 8, !dbg !DILocation(line: 1, column: 1, scope: !131)
  %t11 = mul nsw i32 %t9, %t10, !dbg !DILocation(line: 1, column: 1, scope: !131)
  store i32 %t11, ptr %v_p_s145, align 8, !dbg !DILocation(line: 1, column: 1, scope: !131)
  %t13 = load i32, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !131)
  %t14 = sext i32 %t13 to i64, !dbg !DILocation(line: 1, column: 1, scope: !131)
  %t15 = sub nsw i64 0, %t14, !dbg !DILocation(line: 1, column: 1, scope: !131)
  %t16 = trunc i64 %t15 to i32, !dbg !DILocation(line: 1, column: 1, scope: !131)
  store i32 %t16, ptr %v_neg_s154, align 8, !dbg !DILocation(line: 1, column: 1, scope: !131)
  %t17 = load i32, ptr %v_s_s127, align 8, !dbg !DILocation(line: 1, column: 1, scope: !131)
  %t18 = load i32, ptr %v_d_s136, align 8, !dbg !DILocation(line: 1, column: 1, scope: !131)
  %t19 = add nsw i32 %t17, %t18, !dbg !DILocation(line: 1, column: 1, scope: !131)
  %t20 = load i32, ptr %v_p_s145, align 8, !dbg !DILocation(line: 1, column: 1, scope: !131)
  %t21 = add nsw i32 %t19, %t20, !dbg !DILocation(line: 1, column: 1, scope: !131)
  %t22 = load i32, ptr %v_neg_s154, align 8, !dbg !DILocation(line: 1, column: 1, scope: !131)
  %t23 = add nsw i32 %t21, %t22, !dbg !DILocation(line: 1, column: 1, scope: !131)
  call void @llvm.lifetime.end.p0(i64 4, ptr %v_a), !dbg !DILocation(line: 1, column: 1, scope: !131)
  call void @llvm.lifetime.end.p0(i64 4, ptr %v_b), !dbg !DILocation(line: 1, column: 1, scope: !131)
  call void @llvm.lifetime.end.p0(i64 4, ptr %v_s_s127), !dbg !DILocation(line: 1, column: 1, scope: !131)
  call void @llvm.lifetime.end.p0(i64 4, ptr %v_d_s136), !dbg !DILocation(line: 1, column: 1, scope: !131)
  call void @llvm.lifetime.end.p0(i64 4, ptr %v_p_s145), !dbg !DILocation(line: 1, column: 1, scope: !131)
  call void @llvm.lifetime.end.p0(i64 4, ptr %v_neg_s154), !dbg !DILocation(line: 1, column: 1, scope: !131)
  ret i32 %t23, !dbg !DILocation(line: 1, column: 1, scope: !131)
}
!192 = distinct !DISubprogram(name: "unsigned_u32_ops", scope: !11, file: !11, line: 172, type: !13, spFlags: DISPFlagDefinition, unit: !10)
; FN unsigned_u32_ops
define hidden noundef i32 @unsigned_u32_ops(i32 noundef %p_a, i32 noundef %p_b) readonly nounwind !dbg !192 {
  %v_a = alloca i32, align 8
  %v_b = alloca i32, align 8
  %v_s_s188 = alloca i32, align 8
  %v_d_s197 = alloca i32, align 8
  %v_p_s206 = alloca i32, align 8
  call void @llvm.lifetime.start.p0(i64 4, ptr %v_a), !dbg !DILocation(line: 1, column: 1, scope: !192)
  call void @llvm.lifetime.start.p0(i64 4, ptr %v_b), !dbg !DILocation(line: 1, column: 1, scope: !192)
  call void @llvm.lifetime.start.p0(i64 4, ptr %v_s_s188), !dbg !DILocation(line: 1, column: 1, scope: !192)
  call void @llvm.lifetime.start.p0(i64 4, ptr %v_d_s197), !dbg !DILocation(line: 1, column: 1, scope: !192)
  call void @llvm.lifetime.start.p0(i64 4, ptr %v_p_s206), !dbg !DILocation(line: 1, column: 1, scope: !192)
  store i32 %p_a, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !192)
  store i32 %p_b, ptr %v_b, align 8, !dbg !DILocation(line: 1, column: 1, scope: !192)
  %t3 = load i32, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !192)
  %t4 = load i32, ptr %v_b, align 8, !dbg !DILocation(line: 1, column: 1, scope: !192)
  %t5 = add i32 %t3, %t4, !dbg !DILocation(line: 1, column: 1, scope: !192)
  store i32 %t5, ptr %v_s_s188, align 8, !dbg !DILocation(line: 1, column: 1, scope: !192)
  %t6 = load i32, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !192)
  %t7 = load i32, ptr %v_b, align 8, !dbg !DILocation(line: 1, column: 1, scope: !192)
  %t8 = sub i32 %t6, %t7, !dbg !DILocation(line: 1, column: 1, scope: !192)
  store i32 %t8, ptr %v_d_s197, align 8, !dbg !DILocation(line: 1, column: 1, scope: !192)
  %t9 = load i32, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !192)
  %t10 = load i32, ptr %v_b, align 8, !dbg !DILocation(line: 1, column: 1, scope: !192)
  %t11 = mul i32 %t9, %t10, !dbg !DILocation(line: 1, column: 1, scope: !192)
  store i32 %t11, ptr %v_p_s206, align 8, !dbg !DILocation(line: 1, column: 1, scope: !192)
  %t12 = load i32, ptr %v_s_s188, align 8, !dbg !DILocation(line: 1, column: 1, scope: !192)
  %t13 = load i32, ptr %v_d_s197, align 8, !dbg !DILocation(line: 1, column: 1, scope: !192)
  %t14 = add i32 %t12, %t13, !dbg !DILocation(line: 1, column: 1, scope: !192)
  %t15 = load i32, ptr %v_p_s206, align 8, !dbg !DILocation(line: 1, column: 1, scope: !192)
  %t16 = add i32 %t14, %t15, !dbg !DILocation(line: 1, column: 1, scope: !192)
  call void @llvm.lifetime.end.p0(i64 4, ptr %v_a), !dbg !DILocation(line: 1, column: 1, scope: !192)
  call void @llvm.lifetime.end.p0(i64 4, ptr %v_b), !dbg !DILocation(line: 1, column: 1, scope: !192)
  call void @llvm.lifetime.end.p0(i64 4, ptr %v_s_s188), !dbg !DILocation(line: 1, column: 1, scope: !192)
  call void @llvm.lifetime.end.p0(i64 4, ptr %v_d_s197), !dbg !DILocation(line: 1, column: 1, scope: !192)
  call void @llvm.lifetime.end.p0(i64 4, ptr %v_p_s206), !dbg !DILocation(line: 1, column: 1, scope: !192)
  ret i32 %t16, !dbg !DILocation(line: 1, column: 1, scope: !192)
}
!242 = distinct !DISubprogram(name: "main", scope: !11, file: !11, line: 222, type: !13, spFlags: DISPFlagDefinition, unit: !10)
; FN main
define hidden i32 @main(i32 noundef %argc, ptr nocapture noundef %argv) nounwind !dbg !242 {
entry:
  %v_r1_s231 = alloca i64, align 8
  %v_r2_s243 = alloca i64, align 8
  %v_r3_s255 = alloca i32, align 8
  %v_r4_s267 = alloca i32, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_r1_s231), !dbg !DILocation(line: 1, column: 1, scope: !242)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_r2_s243), !dbg !DILocation(line: 1, column: 1, scope: !242)
  call void @llvm.lifetime.start.p0(i64 4, ptr %v_r3_s255), !dbg !DILocation(line: 1, column: 1, scope: !242)
  call void @llvm.lifetime.start.p0(i64 4, ptr %v_r4_s267), !dbg !DILocation(line: 1, column: 1, scope: !242)
  %t13 = call i64 @signed_i64_ops(i64 10, i64 20), !dbg !DILocation(line: 1, column: 1, scope: !242)
  store i64 %t13, ptr %v_r1_s231, align 8, !dbg !DILocation(line: 1, column: 1, scope: !242)
  %t16 = call i64 @unsigned_u64_ops(i64 10, i64 20), !dbg !DILocation(line: 1, column: 1, scope: !242)
  store i64 %t16, ptr %v_r2_s243, align 8, !dbg !DILocation(line: 1, column: 1, scope: !242)
  %t19 = trunc i64 10 to i32, !dbg !DILocation(line: 1, column: 1, scope: !242)
  %t20 = trunc i64 20 to i32, !dbg !DILocation(line: 1, column: 1, scope: !242)
  %t21 = call i32 @signed_i32_ops(i32 %t19, i32 %t20), !dbg !DILocation(line: 1, column: 1, scope: !242)
  store i32 %t21, ptr %v_r3_s255, align 8, !dbg !DILocation(line: 1, column: 1, scope: !242)
  %t24 = trunc i64 10 to i32, !dbg !DILocation(line: 1, column: 1, scope: !242)
  %t25 = trunc i64 20 to i32, !dbg !DILocation(line: 1, column: 1, scope: !242)
  %t26 = call i32 @unsigned_u32_ops(i32 %t24, i32 %t25), !dbg !DILocation(line: 1, column: 1, scope: !242)
  store i32 %t26, ptr %v_r4_s267, align 8, !dbg !DILocation(line: 1, column: 1, scope: !242)
  %t27 = load i64, ptr %v_r1_s231, align 8, !dbg !DILocation(line: 1, column: 1, scope: !242)
  call void @oo_print_int(i64 %t27), !dbg !DILocation(line: 1, column: 1, scope: !242)
  call void @oo_println(), !dbg !DILocation(line: 1, column: 1, scope: !242)
  %t28 = load i64, ptr %v_r2_s243, align 8, !dbg !DILocation(line: 1, column: 1, scope: !242)
  call void @oo_print_int(i64 %t28), !dbg !DILocation(line: 1, column: 1, scope: !242)
  call void @oo_println(), !dbg !DILocation(line: 1, column: 1, scope: !242)
  %t29 = load i32, ptr %v_r3_s255, align 8, !dbg !DILocation(line: 1, column: 1, scope: !242)
  %t30 = sext i32 %t29 to i64, !dbg !DILocation(line: 1, column: 1, scope: !242)
  call void @oo_print_int(i64 %t30), !dbg !DILocation(line: 1, column: 1, scope: !242)
  call void @oo_println(), !dbg !DILocation(line: 1, column: 1, scope: !242)
  %t31 = load i32, ptr %v_r4_s267, align 8, !dbg !DILocation(line: 1, column: 1, scope: !242)
  %t32 = zext i32 %t31 to i64, !dbg !DILocation(line: 1, column: 1, scope: !242)
  call void @oo_print_int(i64 %t32), !dbg !DILocation(line: 1, column: 1, scope: !242)
  call void @oo_println(), !dbg !DILocation(line: 1, column: 1, scope: !242)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_r1_s231), !dbg !DILocation(line: 1, column: 1, scope: !242)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_r2_s243), !dbg !DILocation(line: 1, column: 1, scope: !242)
  call void @llvm.lifetime.end.p0(i64 4, ptr %v_r3_s255), !dbg !DILocation(line: 1, column: 1, scope: !242)
  call void @llvm.lifetime.end.p0(i64 4, ptr %v_r4_s267), !dbg !DILocation(line: 1, column: 1, scope: !242)
  ret i32 0, !dbg !DILocation(line: 1, column: 1, scope: !242)
}
