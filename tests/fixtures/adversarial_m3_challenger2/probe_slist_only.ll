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
!11 = !DIFile(filename: "oodac/tests/fixtures/adversarial_m3_challenger2/probe_slist_only.oo", directory: ".")
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
declare void @oo_slist_new(ptr noalias sret(%OoSList) align 8) nounwind
declare void @oo_slist_push(ptr noalias sret(%OoSList) align 8, ptr byval(%OoSList) align 8, { ptr, i64 }) nounwind
declare i64 @oo_slist_len(ptr byval(%OoSList) align 8) nounwind
declare { ptr, i64 } @oo_str_lit(ptr) nounwind
declare void @oo_str_retain({ ptr, i64 }) nounwind
declare void @oo_str_release({ ptr, i64 }) nounwind
declare void @oo_slist_retain(ptr byval(%OoSList) align 8) nounwind
declare void @oo_slist_release(ptr byval(%OoSList) align 8) nounwind
declare ptr @oo_list_alloc_payload(i64, i64) nounwind
declare void @oo_list_quota_release_bytes(i64, i64) nounwind
declare void @oo_payload_free(ptr) nounwind
!21 = distinct !DISubprogram(name: "count_slist", scope: !11, file: !11, line: 1, type: !13, spFlags: DISPFlagDefinition, unit: !10)
; FN count_slist
@.s28 = private unnamed_addr constant [6 x i8] c"alpha\00"
@.s37 = private unnamed_addr constant [5 x i8] c"beta\00"
define hidden noundef i64 @count_slist() readonly nounwind !dbg !21 {
  %a3 = alloca %OoSList, align 8
  %v_words_s11 = alloca %OoSList, align 8
  %a8 = alloca %OoStr, align 8
  %a7 = alloca %OoSList, align 8
  %a14 = alloca %OoStr, align 8
  %a13 = alloca %OoSList, align 8
  %v_count_s41 = alloca i64, align 8
  call void @llvm.lifetime.start.p0(i64 24, ptr %a3), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.start.p0(i64 24, ptr %v_words_s11), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.start.p0(i64 16, ptr %a8), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.start.p0(i64 24, ptr %a7), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.start.p0(i64 16, ptr %a14), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.start.p0(i64 24, ptr %a13), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_count_s41), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @oo_slist_new(ptr sret(%OoSList) align 8 %a3), !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t4 = load %OoSList, ptr %a3, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  store %OoSList %t4, ptr %v_words_s11, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t5 = getelementptr inbounds [6 x i8], ptr @.s28, i64 0, i64 0, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t6 = call { ptr, i64 } @oo_str_lit(ptr %t5), !dbg !DILocation(line: 1, column: 1, scope: !21)
  store { ptr, i64 } %t6, ptr %a8, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t9 = load { ptr, i64 }, ptr %a8, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @oo_slist_push(ptr sret(%OoSList) align 8 %a7, ptr byval(%OoSList) align 8 %v_words_s11, { ptr, i64 } %t9), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @oo_slist_release(ptr byval(%OoSList) align 8 %v_words_s11), !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t10 = load %OoSList, ptr %a7, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  store %OoSList %t10, ptr %v_words_s11, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t11 = getelementptr inbounds [5 x i8], ptr @.s37, i64 0, i64 0, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t12 = call { ptr, i64 } @oo_str_lit(ptr %t11), !dbg !DILocation(line: 1, column: 1, scope: !21)
  store { ptr, i64 } %t12, ptr %a14, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t15 = load { ptr, i64 }, ptr %a14, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @oo_slist_push(ptr sret(%OoSList) align 8 %a13, ptr byval(%OoSList) align 8 %v_words_s11, { ptr, i64 } %t15), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @oo_slist_release(ptr byval(%OoSList) align 8 %v_words_s11), !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t16 = load %OoSList, ptr %a13, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  store %OoSList %t16, ptr %v_words_s11, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t17 = call i64 @oo_slist_len(ptr byval(%OoSList) align 8 %v_words_s11), !dbg !DILocation(line: 1, column: 1, scope: !21)
  store i64 %t17, ptr %v_count_s41, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  %t18 = load i64, ptr %v_count_s41, align 8, !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @oo_slist_release(ptr byval(%OoSList) align 8 %v_words_s11), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 24, ptr %a3), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 24, ptr %v_words_s11), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 16, ptr %a8), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 24, ptr %a7), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 16, ptr %a14), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 24, ptr %a13), !dbg !DILocation(line: 1, column: 1, scope: !21)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_count_s41), !dbg !DILocation(line: 1, column: 1, scope: !21)
  ret i64 %t18, !dbg !DILocation(line: 1, column: 1, scope: !21)
}
!74 = distinct !DISubprogram(name: "main", scope: !11, file: !11, line: 54, type: !13, spFlags: DISPFlagDefinition, unit: !10)
; FN main
define hidden i32 @main(i32 noundef %argc, ptr nocapture noundef %argv) nounwind !dbg !74 {
entry:
  %v_res_s63 = alloca i64, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_res_s63), !dbg !DILocation(line: 1, column: 1, scope: !74)
  %t11 = call i64 @count_slist(), !dbg !DILocation(line: 1, column: 1, scope: !74)
  store i64 %t11, ptr %v_res_s63, align 8, !dbg !DILocation(line: 1, column: 1, scope: !74)
  %t12 = load i64, ptr %v_res_s63, align 8, !dbg !DILocation(line: 1, column: 1, scope: !74)
  %t14 = icmp eq i64 %t12, 2, !dbg !DILocation(line: 1, column: 1, scope: !74)
  br i1 %t14, label %then14, label %else14, !dbg !DILocation(line: 1, column: 1, scope: !74)
then14:
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_res_s63), !dbg !DILocation(line: 1, column: 1, scope: !74)
  ret i32 0, !dbg !DILocation(line: 1, column: 1, scope: !74)
else14:
  br label %end14, !dbg !DILocation(line: 1, column: 1, scope: !74)
end14:
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_res_s63), !dbg !DILocation(line: 1, column: 1, scope: !74)
  ret i32 0, !dbg !DILocation(line: 1, column: 1, scope: !74)
}
