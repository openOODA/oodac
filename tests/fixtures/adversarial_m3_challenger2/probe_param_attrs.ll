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
!11 = !DIFile(filename: "oodac/tests/fixtures/adversarial_m3_challenger2/probe_param_attrs.oo", directory: ".")
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
declare i64 @oo_cap_grant_fsread() nounwind
!32 = distinct !DISubprogram(name: "pure_calc", scope: !11, file: !11, line: 12, type: !13, spFlags: DISPFlagDefinition, unit: !10)
%OoL_Counter = type { ptr, i64, i64 }
%St_Counter = type { i64 }
define hidden void @oo_retain_St_Counter(ptr noalias nocapture noundef %p) nounwind {
  ret void
}
define hidden void @oo_release_St_Counter(ptr noalias nocapture noundef %p) nounwind {
  ret void
}
%OoRes_St_Counter = type { i32, %St_Counter, %OoStr }
%OoOpt_St_Counter = type { i32, %St_Counter }
; FN pure_calc
define hidden noundef i64 @pure_calc(i64 noundef %p_a, i64 noundef %p_b) readonly nounwind !dbg !32 {
  %v_a = alloca i64, align 8
  %v_b = alloca i64, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_a), !dbg !DILocation(line: 1, column: 1, scope: !32)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_b), !dbg !DILocation(line: 1, column: 1, scope: !32)
  store i64 %p_a, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !32)
  store i64 %p_b, ptr %v_b, align 8, !dbg !DILocation(line: 1, column: 1, scope: !32)
  %t3 = load i64, ptr %v_a, align 8, !dbg !DILocation(line: 1, column: 1, scope: !32)
  %t5 = mul nsw i64 %t3, 2, !dbg !DILocation(line: 1, column: 1, scope: !32)
  %t6 = load i64, ptr %v_b, align 8, !dbg !DILocation(line: 1, column: 1, scope: !32)
  %t7 = add nsw i64 %t5, %t6, !dbg !DILocation(line: 1, column: 1, scope: !32)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_a), !dbg !DILocation(line: 1, column: 1, scope: !32)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_b), !dbg !DILocation(line: 1, column: 1, scope: !32)
  ret i64 %t7, !dbg !DILocation(line: 1, column: 1, scope: !32)
}
!55 = distinct !DISubprogram(name: "mut_scalar", scope: !11, file: !11, line: 35, type: !13, spFlags: DISPFlagDefinition, unit: !10)
; FN mut_scalar
define hidden noundef i64 @mut_scalar(ptr noalias nocapture noundef %p_val, i64 noundef %p_delta) nounwind !dbg !55 {
  %v_delta = alloca i64, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_delta), !dbg !DILocation(line: 1, column: 1, scope: !55)
  store i64 %p_delta, ptr %v_delta, align 8, !dbg !DILocation(line: 1, column: 1, scope: !55)
  %t3 = load i64, ptr %p_val, align 8, !dbg !DILocation(line: 1, column: 1, scope: !55)
  %t4 = load i64, ptr %v_delta, align 8, !dbg !DILocation(line: 1, column: 1, scope: !55)
  %t5 = add nsw i64 %t3, %t4, !dbg !DILocation(line: 1, column: 1, scope: !55)
  store i64 %t5, ptr %p_val, align 8, !dbg !DILocation(line: 1, column: 1, scope: !55)
  %t6 = load i64, ptr %p_val, align 8, !dbg !DILocation(line: 1, column: 1, scope: !55)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_delta), !dbg !DILocation(line: 1, column: 1, scope: !55)
  ret i64 %t6, !dbg !DILocation(line: 1, column: 1, scope: !55)
}
!85 = distinct !DISubprogram(name: "mut_struct", scope: !11, file: !11, line: 65, type: !13, spFlags: DISPFlagDefinition, unit: !10)
; FN mut_struct
define hidden noundef i64 @mut_struct(ptr noalias nocapture noundef %p_c, i64 noundef %p_step) nounwind !dbg !85 {
  %v_step = alloca i64, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_step), !dbg !DILocation(line: 1, column: 1, scope: !85)
  store i64 %p_step, ptr %v_step, align 8, !dbg !DILocation(line: 1, column: 1, scope: !85)
  %t3 = getelementptr inbounds %St_Counter, ptr %p_c, i32 0, i32 0, !dbg !DILocation(line: 1, column: 1, scope: !85)
  %t4 = getelementptr inbounds %St_Counter, ptr %p_c, i32 0, i32 0, !dbg !DILocation(line: 1, column: 1, scope: !85)
  %t5 = load i64, ptr %t4, align 8, !dbg !DILocation(line: 1, column: 1, scope: !85)
  %t6 = load i64, ptr %v_step, align 8, !dbg !DILocation(line: 1, column: 1, scope: !85)
  %t7 = add nsw i64 %t5, %t6, !dbg !DILocation(line: 1, column: 1, scope: !85)
  store i64 %t7, ptr %t3, align 8, !dbg !DILocation(line: 1, column: 1, scope: !85)
  %t8 = getelementptr inbounds %St_Counter, ptr %p_c, i32 0, i32 0, !dbg !DILocation(line: 1, column: 1, scope: !85)
  %t9 = load i64, ptr %t8, align 8, !dbg !DILocation(line: 1, column: 1, scope: !85)
  %t10 = load i64, ptr %t8, align 8, !dbg !DILocation(line: 1, column: 1, scope: !85)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_step), !dbg !DILocation(line: 1, column: 1, scope: !85)
  ret i64 %t10, !dbg !DILocation(line: 1, column: 1, scope: !85)
}
!118 = distinct !DISubprogram(name: "cap_read", scope: !11, file: !11, line: 98, type: !13, spFlags: DISPFlagDefinition, unit: !10)
; FN cap_read
define hidden noundef i64 @cap_read(i64 noundef %p_fs, i64 noundef %p_factor) nounwind !dbg !118 {
  %v_fs = alloca i64, align 8
  %v_factor = alloca i64, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_fs), !dbg !DILocation(line: 1, column: 1, scope: !118)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_factor), !dbg !DILocation(line: 1, column: 1, scope: !118)
  store i64 %p_fs, ptr %v_fs, align 8, !dbg !DILocation(line: 1, column: 1, scope: !118)
  store i64 %p_factor, ptr %v_factor, align 8, !dbg !DILocation(line: 1, column: 1, scope: !118)
  %t3 = load i64, ptr %v_factor, align 8, !dbg !DILocation(line: 1, column: 1, scope: !118)
  %t5 = mul nsw i64 %t3, 10, !dbg !DILocation(line: 1, column: 1, scope: !118)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_fs), !dbg !DILocation(line: 1, column: 1, scope: !118)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_factor), !dbg !DILocation(line: 1, column: 1, scope: !118)
  ret i64 %t5, !dbg !DILocation(line: 1, column: 1, scope: !118)
}
!140 = distinct !DISubprogram(name: "mem_return", scope: !11, file: !11, line: 120, type: !13, spFlags: DISPFlagDefinition, unit: !10)
; FN mem_return
define hidden void @mem_return(ptr noalias sret(%St_Counter) align 8 %ret, i64 noundef %p_val) nounwind !dbg !140 {
  %v_val = alloca i64, align 8
  %a3 = alloca %St_Counter, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_val), !dbg !DILocation(line: 1, column: 1, scope: !140)
  call void @llvm.lifetime.start.p0(i64 -1, ptr %a3), !dbg !DILocation(line: 1, column: 1, scope: !140)
  store i64 %p_val, ptr %v_val, align 8, !dbg !DILocation(line: 1, column: 1, scope: !140)
  %t4 = load i64, ptr %v_val, align 8, !dbg !DILocation(line: 1, column: 1, scope: !140)
  %t5 = getelementptr inbounds %St_Counter, ptr %a3, i32 0, i32 0, !dbg !DILocation(line: 1, column: 1, scope: !140)
  store i64 %t4, ptr %t5, align 8, !dbg !DILocation(line: 1, column: 1, scope: !140)
  call void @oo_retain_St_Counter(ptr %a3), !dbg !DILocation(line: 1, column: 1, scope: !140)
  %t6 = load %St_Counter, ptr %a3, align 8, !dbg !DILocation(line: 1, column: 1, scope: !140)
  store %St_Counter %t6, ptr %ret, align 8, !dbg !DILocation(line: 1, column: 1, scope: !140)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_val), !dbg !DILocation(line: 1, column: 1, scope: !140)
  call void @llvm.lifetime.end.p0(i64 -1, ptr %a3), !dbg !DILocation(line: 1, column: 1, scope: !140)
  ret void, !dbg !DILocation(line: 1, column: 1, scope: !140)
}
!160 = distinct !DISubprogram(name: "void_worker", scope: !11, file: !11, line: 140, type: !13, spFlags: DISPFlagDefinition, unit: !10)
; FN void_worker
define hidden void @void_worker(i64 noundef %p_x) nounwind !dbg !160 {
  %v_x = alloca i64, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_x), !dbg !DILocation(line: 1, column: 1, scope: !160)
  store i64 %p_x, ptr %v_x, align 8, !dbg !DILocation(line: 1, column: 1, scope: !160)
  %t3 = load i64, ptr %v_x, align 8, !dbg !DILocation(line: 1, column: 1, scope: !160)
  %t5 = icmp sgt i64 %t3, 0, !dbg !DILocation(line: 1, column: 1, scope: !160)
  br i1 %t5, label %then5, label %else5, !dbg !DILocation(line: 1, column: 1, scope: !160)
then5:
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_x), !dbg !DILocation(line: 1, column: 1, scope: !160)
  ret void, !dbg !DILocation(line: 1, column: 1, scope: !160)
else5:
  br label %end5, !dbg !DILocation(line: 1, column: 1, scope: !160)
end5:
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_x), !dbg !DILocation(line: 1, column: 1, scope: !160)
  ret void, !dbg !DILocation(line: 1, column: 1, scope: !160)
}
!178 = distinct !DISubprogram(name: "main", scope: !11, file: !11, line: 158, type: !13, spFlags: DISPFlagDefinition, unit: !10)
; FN main
define hidden i32 @main(i32 noundef %argc, ptr nocapture noundef %argv) nounwind !dbg !178 {
entry:
  %v_fs = alloca i64, align 8
  %v_num_s172 = alloca i64, align 8
  %v_r1_s179 = alloca i64, align 8
  %v_r2_s191 = alloca i64, align 8
  %a17 = alloca %St_Counter, align 8
  %v_c_s206 = alloca %St_Counter, align 8
  %v_r3_s218 = alloca i64, align 8
  %v_r4_s232 = alloca i64, align 8
  %a33 = alloca %St_Counter, align 8
  %v_c2_s244 = alloca %St_Counter, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_fs), !dbg !DILocation(line: 1, column: 1, scope: !178)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_num_s172), !dbg !DILocation(line: 1, column: 1, scope: !178)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_r1_s179), !dbg !DILocation(line: 1, column: 1, scope: !178)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_r2_s191), !dbg !DILocation(line: 1, column: 1, scope: !178)
  call void @llvm.lifetime.start.p0(i64 -1, ptr %a17), !dbg !DILocation(line: 1, column: 1, scope: !178)
  call void @llvm.lifetime.start.p0(i64 -1, ptr %v_c_s206), !dbg !DILocation(line: 1, column: 1, scope: !178)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_r3_s218), !dbg !DILocation(line: 1, column: 1, scope: !178)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_r4_s232), !dbg !DILocation(line: 1, column: 1, scope: !178)
  call void @llvm.lifetime.start.p0(i64 -1, ptr %a33), !dbg !DILocation(line: 1, column: 1, scope: !178)
  call void @llvm.lifetime.start.p0(i64 -1, ptr %v_c2_s244), !dbg !DILocation(line: 1, column: 1, scope: !178)
  %g_fs = call i64 @oo_cap_grant_fsread(), !dbg !DILocation(line: 1, column: 1, scope: !178)
  store i64 %g_fs, ptr %v_fs, align 8, !dbg !DILocation(line: 1, column: 1, scope: !178)
  store i64 10, ptr %v_num_s172, align 8, !dbg !DILocation(line: 1, column: 1, scope: !178)
  %t12 = load i64, ptr %v_num_s172, align 8, !dbg !DILocation(line: 1, column: 1, scope: !178)
  %t14 = call i64 @pure_calc(i64 %t12, i64 5), !dbg !DILocation(line: 1, column: 1, scope: !178)
  store i64 %t14, ptr %v_r1_s179, align 8, !dbg !DILocation(line: 1, column: 1, scope: !178)
  %t16 = call i64 @mut_scalar(ptr %v_num_s172, i64 3), !dbg !DILocation(line: 1, column: 1, scope: !178)
  store i64 %t16, ptr %v_r2_s191, align 8, !dbg !DILocation(line: 1, column: 1, scope: !178)
  %t19 = getelementptr inbounds %St_Counter, ptr %a17, i32 0, i32 0, !dbg !DILocation(line: 1, column: 1, scope: !178)
  store i64 20, ptr %t19, align 8, !dbg !DILocation(line: 1, column: 1, scope: !178)
  %t20 = load %St_Counter, ptr %a17, align 8, !dbg !DILocation(line: 1, column: 1, scope: !178)
  store %St_Counter %t20, ptr %v_c_s206, align 8, !dbg !DILocation(line: 1, column: 1, scope: !178)
  %t22 = call i64 @mut_struct(ptr noalias nocapture noundef %v_c_s206, i64 4), !dbg !DILocation(line: 1, column: 1, scope: !178)
  store i64 %t22, ptr %v_r3_s218, align 8, !dbg !DILocation(line: 1, column: 1, scope: !178)
  %t23 = load i64, ptr %v_fs, align 8, !dbg !DILocation(line: 1, column: 1, scope: !178)
  %t25 = call i64 @cap_read(i64 %t23, i64 2), !dbg !DILocation(line: 1, column: 1, scope: !178)
  store i64 %t25, ptr %v_r4_s232, align 8, !dbg !DILocation(line: 1, column: 1, scope: !178)
  %t26 = load i64, ptr %v_r1_s179, align 8, !dbg !DILocation(line: 1, column: 1, scope: !178)
  %t27 = load i64, ptr %v_r2_s191, align 8, !dbg !DILocation(line: 1, column: 1, scope: !178)
  %t28 = add nsw i64 %t26, %t27, !dbg !DILocation(line: 1, column: 1, scope: !178)
  %t29 = load i64, ptr %v_r3_s218, align 8, !dbg !DILocation(line: 1, column: 1, scope: !178)
  %t30 = add nsw i64 %t28, %t29, !dbg !DILocation(line: 1, column: 1, scope: !178)
  %t31 = load i64, ptr %v_r4_s232, align 8, !dbg !DILocation(line: 1, column: 1, scope: !178)
  %t32 = add nsw i64 %t30, %t31, !dbg !DILocation(line: 1, column: 1, scope: !178)
  call void @mem_return(ptr sret(%St_Counter) align 8 %a33, i64 %t32), !dbg !DILocation(line: 1, column: 1, scope: !178)
  %t34 = load %St_Counter, ptr %a33, align 8, !dbg !DILocation(line: 1, column: 1, scope: !178)
  store %St_Counter %t34, ptr %v_c2_s244, align 8, !dbg !DILocation(line: 1, column: 1, scope: !178)
  %t35 = getelementptr inbounds %St_Counter, ptr %v_c2_s244, i32 0, i32 0, !dbg !DILocation(line: 1, column: 1, scope: !178)
  %t36 = load i64, ptr %t35, align 8, !dbg !DILocation(line: 1, column: 1, scope: !178)
  call void @void_worker(i64 %t36), !dbg !DILocation(line: 1, column: 1, scope: !178)
  call void @oo_release_St_Counter(ptr %v_c2_s244), !dbg !DILocation(line: 1, column: 1, scope: !178)
  call void @oo_release_St_Counter(ptr %v_c_s206), !dbg !DILocation(line: 1, column: 1, scope: !178)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_fs), !dbg !DILocation(line: 1, column: 1, scope: !178)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_num_s172), !dbg !DILocation(line: 1, column: 1, scope: !178)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_r1_s179), !dbg !DILocation(line: 1, column: 1, scope: !178)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_r2_s191), !dbg !DILocation(line: 1, column: 1, scope: !178)
  call void @llvm.lifetime.end.p0(i64 -1, ptr %a17), !dbg !DILocation(line: 1, column: 1, scope: !178)
  call void @llvm.lifetime.end.p0(i64 -1, ptr %v_c_s206), !dbg !DILocation(line: 1, column: 1, scope: !178)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_r3_s218), !dbg !DILocation(line: 1, column: 1, scope: !178)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_r4_s232), !dbg !DILocation(line: 1, column: 1, scope: !178)
  call void @llvm.lifetime.end.p0(i64 -1, ptr %a33), !dbg !DILocation(line: 1, column: 1, scope: !178)
  call void @llvm.lifetime.end.p0(i64 -1, ptr %v_c2_s244), !dbg !DILocation(line: 1, column: 1, scope: !178)
  ret i32 0, !dbg !DILocation(line: 1, column: 1, scope: !178)
}
