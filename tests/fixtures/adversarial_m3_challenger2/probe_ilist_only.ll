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
!11 = !DIFile(filename: "oodac/tests/fixtures/adversarial_m3_challenger2/probe_ilist_only.oo", directory: ".")
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
declare void @oo_ilist_new(ptr noalias sret(%OoIList) align 8) nounwind
declare void @oo_ilist_push(ptr noalias sret(%OoIList) align 8, ptr byval(%OoIList) align 8, i64) nounwind
declare i64 @oo_ilist_len(ptr byval(%OoIList) align 8) nounwind
declare i64 @oo_ilist_get(ptr byval(%OoIList) align 8, i64) nounwind
declare void @oo_ilist_retain(ptr byval(%OoIList) align 8) nounwind
declare void @oo_ilist_release(ptr byval(%OoIList) align 8) nounwind
declare ptr @oo_list_alloc_payload(i64, i64) nounwind
declare void @oo_list_quota_release_bytes(i64, i64) nounwind
declare void @oo_payload_free(ptr) nounwind
!21 = distinct !DISubprogram(name: "sum_ilist", scope: !11, file: !11, line: 1, type: !13, spFlags: DISPFlagDefinition, unit: !10)
; FN sum_ilist
define hidden noundef i64 @sum_ilist(i64 noundef %p_n) readonly nounwind !dbg !21 {
  %v_n = alloca i64, align 8
  %a3 = alloca %OoIList, align 8
  %v_nums_s14 = alloca %OoIList, align 8
  %v_i_s27 = alloca i64, align 8
  %a10 = alloca %OoIList, align 8
  %v_total_s56 = alloca i64, align 8
  %v_j_s64 = alloca i64, align 8
  %v_count_s71 = alloca i64, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_n), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.start.p0(i64 24, ptr %a3), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.start.p0(i64 24, ptr %v_nums_s14), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_i_s27), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.start.p0(i64 24, ptr %a10), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_total_s56), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_j_s64), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_count_s71), !dbg !DILocation(line: 1, column: 1, scope: !21)
  store i64 %p_n, ptr %v_n, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @oo_ilist_new(ptr sret(%OoIList) align 8 %a3), !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t4 = load %OoIList, ptr %a3, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  store %OoIList %t4, ptr %v_nums_s14, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  store i64 1, ptr %v_i_s27, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  br label %wcond6, !dbg !DILocation(line: 1, column: 1, scope: !21)
wcond6:
  %t6 = load i64, ptr %v_i_s27, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t7 = load i64, ptr %v_n, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t8 = icmp sle i64 %t6, %t7, !dbg !DILocation(line: 1, column: 1, scope: !21)
  br i1 %t8, label %wbody6, label %wend6, !dbg !DILocation(line: 1, column: 1, scope: !21)
wbody6:
  %t9 = load i64, ptr %v_i_s27, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @oo_ilist_push(ptr sret(%OoIList) align 8 %a10, ptr byval(%OoIList) align 8 %v_nums_s14, i64 %t9), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @oo_ilist_release(ptr byval(%OoIList) align 8 %v_nums_s14), !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t12 = load %OoIList, ptr %a10, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  store %OoIList %t12, ptr %v_nums_s14, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t13 = load i64, ptr %v_i_s27, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t15 = add nsw i64 %t13, 1, !dbg !DILocation(line: 1, column: 1, scope: !21)
  store i64 %t15, ptr %v_i_s27, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  br label %wcond6, !dbg !DILocation(line: 1, column: 1, scope: !21)
wend6:
  store i64 0, ptr %v_total_s56, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  store i64 0, ptr %v_j_s64, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t18 = call i64 @oo_ilist_len(ptr byval(%OoIList) align 8 %v_nums_s14), !dbg !DILocation(line: 1, column: 1, scope: !21)
  store i64 %t18, ptr %v_count_s71, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  br label %wcond19, !dbg !DILocation(line: 1, column: 1, scope: !21)
wcond19:
  %t19 = load i64, ptr %v_j_s64, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t20 = load i64, ptr %v_count_s71, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t21 = icmp slt i64 %t19, %t20, !dbg !DILocation(line: 1, column: 1, scope: !21)
  br i1 %t21, label %wbody19, label %wend19, !dbg !DILocation(line: 1, column: 1, scope: !21)
wbody19:
  %t22 = load i64, ptr %v_total_s56, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t23 = load i64, ptr %v_j_s64, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t24 = call i64 @oo_ilist_get(ptr byval(%OoIList) align 8 %v_nums_s14, i64 %t23), !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t25 = add nsw i64 %t22, %t24, !dbg !DILocation(line: 1, column: 1, scope: !21)
  store i64 %t25, ptr %v_total_s56, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t26 = load i64, ptr %v_j_s64, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t28 = add nsw i64 %t26, 1, !dbg !DILocation(line: 1, column: 1, scope: !21)
  store i64 %t28, ptr %v_j_s64, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  br label %wcond19, !dbg !DILocation(line: 1, column: 1, scope: !21)
wend19:
  %t29 = load i64, ptr %v_total_s56, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @oo_ilist_release(ptr byval(%OoIList) align 8 %v_nums_s14), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_n), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 24, ptr %a3), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 24, ptr %v_nums_s14), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_i_s27), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 24, ptr %a10), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_total_s56), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_j_s64), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_count_s71), !dbg !DILocation(line: 1, column: 1, scope: !21)
  ret i64 %t29, !dbg !DILocation(line: 1, column: 1, scope: !21)
}
!127 = distinct !DISubprogram(name: "main", scope: !11, file: !11, line: 107, type: !13, spFlags: DISPFlagDefinition, unit: !10)
; FN main
define hidden i32 @main(i32 noundef %argc, ptr nocapture noundef %argv) nounwind !dbg !127 {
entry:
  %v_res_s116 = alloca i64, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_res_s116), !dbg !DILocation(line: 1, column: 1, scope: !127)
  %t12 = call i64 @sum_ilist(i64 10), !dbg !DILocation(line: 1, column: 1, scope: !127)
  store i64 %t12, ptr %v_res_s116, align 8, !dbg !DILocation(line: 1, column: 1, scope: !127)
  %t13 = load i64, ptr %v_res_s116, align 8, !dbg !DILocation(line: 1, column: 1, scope: !127)
  %t15 = icmp eq i64 %t13, 55, !dbg !DILocation(line: 1, column: 1, scope: !127)
  br i1 %t15, label %then15, label %else15, !dbg !DILocation(line: 1, column: 1, scope: !127)
then15:
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_res_s116), !dbg !DILocation(line: 1, column: 1, scope: !127)
  ret i32 0, !dbg !DILocation(line: 1, column: 1, scope: !127)
else15:
  br label %end15, !dbg !DILocation(line: 1, column: 1, scope: !127)
end15:
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_res_s116), !dbg !DILocation(line: 1, column: 1, scope: !127)
  ret i32 0, !dbg !DILocation(line: 1, column: 1, scope: !127)
}
