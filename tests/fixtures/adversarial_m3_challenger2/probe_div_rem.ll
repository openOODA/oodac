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
!11 = !DIFile(filename: "oodac/tests/fixtures/adversarial_m3_challenger2/probe_div_rem.oo", directory: ".")
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
declare void @oo_process_exit(i64) noreturn nounwind
declare void @oo_println() nounwind
declare void @oo_print_int(i64) nounwind
!21 = distinct !DISubprogram(name: "signed_div_rem", scope: !11, file: !11, line: 1, type: !13, spFlags: DISPFlagDefinition, unit: !10)
; FN signed_div_rem
define hidden noundef i64 @signed_div_rem(i64 noundef %p_a, i64 noundef %p_b) readonly nounwind !dbg !21 {
  %v_a = alloca i64, align 8
  %v_b = alloca i64, align 8
  %v_q_s17 = alloca i64, align 8
  %v_r_s26 = alloca i64, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_a), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_b), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_q_s17), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_r_s26), !dbg !DILocation(line: 1, column: 1, scope: !21)
  store i64 %p_a, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  store i64 %p_b, ptr %v_b, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t3 = load i64, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t4 = load i64, ptr %v_b, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t5 = icmp eq i64 %t4, 0, !dbg !DILocation(line: 1, column: 1, scope: !21)
  br i1 %t5, label %div05, label %divok5, !dbg !DILocation(line: 1, column: 1, scope: !21)
div05:
  call void @oo_process_exit(i64 1), !dbg !DILocation(line: 1, column: 1, scope: !21)
  unreachable, !dbg !DILocation(line: 1, column: 1, scope: !21)
divok5:
  %t6 = xor i1 %t5, true, !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.assume(i1 %t6), !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t7 = icmp eq i64 %t3, -9223372036854775808, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t8 = icmp eq i64 %t4, -1, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t9 = and i1 %t7, %t8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t10 = select i1 %t9, i64 1, i64 %t4, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t11 = sdiv i64 %t3, %t10, !dbg !DILocation(line: 1, column: 1, scope: !21)
  store i64 %t11, ptr %v_q_s17, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t12 = load i64, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t13 = load i64, ptr %v_b, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t14 = icmp eq i64 %t13, 0, !dbg !DILocation(line: 1, column: 1, scope: !21)
  br i1 %t14, label %div014, label %divok14, !dbg !DILocation(line: 1, column: 1, scope: !21)
div014:
  call void @oo_process_exit(i64 1), !dbg !DILocation(line: 1, column: 1, scope: !21)
  unreachable, !dbg !DILocation(line: 1, column: 1, scope: !21)
divok14:
  %t15 = xor i1 %t14, true, !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.assume(i1 %t15), !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t16 = icmp eq i64 %t12, -9223372036854775808, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t17 = icmp eq i64 %t13, -1, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t18 = and i1 %t16, %t17, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t19 = select i1 %t18, i64 1, i64 %t13, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t20 = srem i64 %t12, %t19, !dbg !DILocation(line: 1, column: 1, scope: !21)
  store i64 %t20, ptr %v_r_s26, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t21 = load i64, ptr %v_q_s17, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t22 = load i64, ptr %v_r_s26, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t23 = add nsw i64 %t21, %t22, !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_a), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_b), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_q_s17), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_r_s26), !dbg !DILocation(line: 1, column: 1, scope: !21)
  ret i64 %t23, !dbg !DILocation(line: 1, column: 1, scope: !21)
}
!60 = distinct !DISubprogram(name: "unsigned_div_rem", scope: !11, file: !11, line: 40, type: !13, spFlags: DISPFlagDefinition, unit: !10)
; FN unsigned_div_rem
define hidden noundef i64 @unsigned_div_rem(i64 noundef %p_a, i64 noundef %p_b) readonly nounwind !dbg !60 {
  %v_a = alloca i64, align 8
  %v_b = alloca i64, align 8
  %v_q_s56 = alloca i64, align 8
  %v_r_s65 = alloca i64, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_a), !dbg !DILocation(line: 1, column: 1, scope: !60)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_b), !dbg !DILocation(line: 1, column: 1, scope: !60)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_q_s56), !dbg !DILocation(line: 1, column: 1, scope: !60)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_r_s65), !dbg !DILocation(line: 1, column: 1, scope: !60)
  store i64 %p_a, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !60)
  store i64 %p_b, ptr %v_b, align 8, !dbg !DILocation(line: 1, column: 1, scope: !60)
  %t3 = load i64, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !60)
  %t4 = load i64, ptr %v_b, align 8, !dbg !DILocation(line: 1, column: 1, scope: !60)
  %t5 = icmp eq i64 %t4, 0, !dbg !DILocation(line: 1, column: 1, scope: !60)
  br i1 %t5, label %div05, label %divok5, !dbg !DILocation(line: 1, column: 1, scope: !60)
div05:
  call void @oo_process_exit(i64 1), !dbg !DILocation(line: 1, column: 1, scope: !60)
  unreachable, !dbg !DILocation(line: 1, column: 1, scope: !60)
divok5:
  %t6 = xor i1 %t5, true, !dbg !DILocation(line: 1, column: 1, scope: !60)
  call void @llvm.assume(i1 %t6), !dbg !DILocation(line: 1, column: 1, scope: !60)
  %t7 = udiv i64 %t3, %t4, !dbg !DILocation(line: 1, column: 1, scope: !60)
  store i64 %t7, ptr %v_q_s56, align 8, !dbg !DILocation(line: 1, column: 1, scope: !60)
  %t8 = load i64, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !60)
  %t9 = load i64, ptr %v_b, align 8, !dbg !DILocation(line: 1, column: 1, scope: !60)
  %t10 = icmp eq i64 %t9, 0, !dbg !DILocation(line: 1, column: 1, scope: !60)
  br i1 %t10, label %div010, label %divok10, !dbg !DILocation(line: 1, column: 1, scope: !60)
div010:
  call void @oo_process_exit(i64 1), !dbg !DILocation(line: 1, column: 1, scope: !60)
  unreachable, !dbg !DILocation(line: 1, column: 1, scope: !60)
divok10:
  %t11 = xor i1 %t10, true, !dbg !DILocation(line: 1, column: 1, scope: !60)
  call void @llvm.assume(i1 %t11), !dbg !DILocation(line: 1, column: 1, scope: !60)
  %t12 = urem i64 %t8, %t9, !dbg !DILocation(line: 1, column: 1, scope: !60)
  store i64 %t12, ptr %v_r_s65, align 8, !dbg !DILocation(line: 1, column: 1, scope: !60)
  %t13 = load i64, ptr %v_q_s56, align 8, !dbg !DILocation(line: 1, column: 1, scope: !60)
  %t14 = load i64, ptr %v_r_s65, align 8, !dbg !DILocation(line: 1, column: 1, scope: !60)
  %t15 = add i64 %t13, %t14, !dbg !DILocation(line: 1, column: 1, scope: !60)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_a), !dbg !DILocation(line: 1, column: 1, scope: !60)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_b), !dbg !DILocation(line: 1, column: 1, scope: !60)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_q_s56), !dbg !DILocation(line: 1, column: 1, scope: !60)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_r_s65), !dbg !DILocation(line: 1, column: 1, scope: !60)
  ret i64 %t15, !dbg !DILocation(line: 1, column: 1, scope: !60)
}
!99 = distinct !DISubprogram(name: "main", scope: !11, file: !11, line: 79, type: !13, spFlags: DISPFlagDefinition, unit: !10)
; FN main
define hidden i32 @main(i32 noundef %argc, ptr nocapture noundef %argv) nounwind !dbg !99 {
entry:
  %v_s_s88 = alloca i64, align 8
  %v_u_s100 = alloca i64, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_s_s88), !dbg !DILocation(line: 1, column: 1, scope: !99)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_u_s100), !dbg !DILocation(line: 1, column: 1, scope: !99)
  %t13 = call i64 @signed_div_rem(i64 20, i64 3), !dbg !DILocation(line: 1, column: 1, scope: !99)
  store i64 %t13, ptr %v_s_s88, align 8, !dbg !DILocation(line: 1, column: 1, scope: !99)
  %t16 = call i64 @unsigned_div_rem(i64 20, i64 3), !dbg !DILocation(line: 1, column: 1, scope: !99)
  store i64 %t16, ptr %v_u_s100, align 8, !dbg !DILocation(line: 1, column: 1, scope: !99)
  %t17 = load i64, ptr %v_s_s88, align 8, !dbg !DILocation(line: 1, column: 1, scope: !99)
  call void @oo_print_int(i64 %t17), !dbg !DILocation(line: 1, column: 1, scope: !99)
  call void @oo_println(), !dbg !DILocation(line: 1, column: 1, scope: !99)
  %t18 = load i64, ptr %v_u_s100, align 8, !dbg !DILocation(line: 1, column: 1, scope: !99)
  call void @oo_print_int(i64 %t18), !dbg !DILocation(line: 1, column: 1, scope: !99)
  call void @oo_println(), !dbg !DILocation(line: 1, column: 1, scope: !99)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_s_s88), !dbg !DILocation(line: 1, column: 1, scope: !99)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_u_s100), !dbg !DILocation(line: 1, column: 1, scope: !99)
  ret i32 0, !dbg !DILocation(line: 1, column: 1, scope: !99)
}
