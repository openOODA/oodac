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
!11 = !DIFile(filename: "oodac/tests/fixtures/adversarial_m3_challenger2/probe_complex_catalog.oo", directory: ".")
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
declare { ptr, i64 } @oo_str_lit(ptr) nounwind
declare void @oo_str_retain({ ptr, i64 }) nounwind
declare void @oo_str_release({ ptr, i64 }) nounwind
!36 = distinct !DISubprogram(name: "check_opt", scope: !11, file: !11, line: 16, type: !13, spFlags: DISPFlagDefinition, unit: !10)
%OoL_Item = type { ptr, i64, i64 }
%St_Item = type { i64, %OoStr }
define hidden void @oo_retain_St_Item(ptr noalias nocapture noundef %p) nounwind {
  %t10 = getelementptr inbounds %St_Item, ptr %p, i32 0, i32 1
  %t11 = load { ptr, i64 }, ptr %t10, align 8
  call void @oo_str_retain({ ptr, i64 } %t11)
  ret void
}
define hidden void @oo_release_St_Item(ptr noalias nocapture noundef %p) nounwind {
  %t10 = getelementptr inbounds %St_Item, ptr %p, i32 0, i32 1
  %t11 = load { ptr, i64 }, ptr %t10, align 8
  call void @oo_str_release({ ptr, i64 } %t11)
  ret void
}
%OoRes_St_Item = type { i32, %St_Item, %OoStr }
%OoOpt_St_Item = type { i32, %St_Item }
; FN check_opt
define hidden noundef i64 @check_opt(ptr noalias nocapture byval(%OoOptI) align 8 %p_opt) readonly nounwind !dbg !36 {
  %v_opt = alloca %OoOptI, align 8
  %v_v_4 = alloca i64, align 8
  call void @llvm.lifetime.start.p0(i64 16, ptr %v_opt), !dbg !DILocation(line: 1, column: 1, scope: !36)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_v_4), !dbg !DILocation(line: 1, column: 1, scope: !36)
  %t2 = load %OoOptI, ptr %p_opt, align 8, !dbg !DILocation(line: 1, column: 1, scope: !36)
  store %OoOptI %t2, ptr %v_opt, align 8, !dbg !DILocation(line: 1, column: 1, scope: !36)
  %t4 = getelementptr inbounds %OoOptI, ptr %v_opt, i32 0, i32 0, !dbg !DILocation(line: 1, column: 1, scope: !36)
  %t5 = load i32, ptr %t4, align 4, !dbg !DILocation(line: 1, column: 1, scope: !36)
  %t6 = icmp ne i32 %t5, 0, !dbg !DILocation(line: 1, column: 1, scope: !36)
  br i1 %t6, label %marm14, label %marm24, !dbg !DILocation(line: 1, column: 1, scope: !36)
marm14:
  %t7 = getelementptr inbounds %OoOptI, ptr %v_opt, i32 0, i32 1, !dbg !DILocation(line: 1, column: 1, scope: !36)
  %t8 = load i64, ptr %t7, align 8, !dbg !DILocation(line: 1, column: 1, scope: !36)
  store i64 %t8, ptr %v_v_4, align 8, !dbg !DILocation(line: 1, column: 1, scope: !36)
  %t10 = load i64, ptr %v_v_4, align 8, !dbg !DILocation(line: 1, column: 1, scope: !36)
  call void @llvm.lifetime.end.p0(i64 16, ptr %v_opt), !dbg !DILocation(line: 1, column: 1, scope: !36)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_v_4), !dbg !DILocation(line: 1, column: 1, scope: !36)
  ret i64 %t10, !dbg !DILocation(line: 1, column: 1, scope: !36)
marm24:
  call void @llvm.lifetime.end.p0(i64 16, ptr %v_opt), !dbg !DILocation(line: 1, column: 1, scope: !36)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_v_4), !dbg !DILocation(line: 1, column: 1, scope: !36)
  ret i64 0, !dbg !DILocation(line: 1, column: 1, scope: !36)
mend4:
  unreachable, !dbg !DILocation(line: 1, column: 1, scope: !36)
}
!72 = distinct !DISubprogram(name: "check_res", scope: !11, file: !11, line: 52, type: !13, spFlags: DISPFlagDefinition, unit: !10)
; FN check_res
define hidden { ptr, i64 } @check_res(ptr noalias nocapture byval(%OoResS) align 8 %p_res) readonly nounwind !dbg !72 {
  %v_res = alloca %OoResS, align 8
  %v_msg_4 = alloca %OoStr, align 8
  %v_err_4 = alloca %OoStr, align 8
  call void @llvm.lifetime.start.p0(i64 24, ptr %v_res), !dbg !DILocation(line: 1, column: 1, scope: !72)
  call void @llvm.lifetime.start.p0(i64 16, ptr %v_msg_4), !dbg !DILocation(line: 1, column: 1, scope: !72)
  call void @llvm.lifetime.start.p0(i64 16, ptr %v_err_4), !dbg !DILocation(line: 1, column: 1, scope: !72)
  %t2 = load %OoResS, ptr %p_res, align 8, !dbg !DILocation(line: 1, column: 1, scope: !72)
  store %OoResS %t2, ptr %v_res, align 8, !dbg !DILocation(line: 1, column: 1, scope: !72)
  %t4 = getelementptr inbounds %OoResS, ptr %v_res, i32 0, i32 0, !dbg !DILocation(line: 1, column: 1, scope: !72)
  %t5 = load i32, ptr %t4, align 4, !dbg !DILocation(line: 1, column: 1, scope: !72)
  %t6 = icmp ne i32 %t5, 0, !dbg !DILocation(line: 1, column: 1, scope: !72)
  br i1 %t6, label %marm14, label %marm24, !dbg !DILocation(line: 1, column: 1, scope: !72)
marm14:
  %t7 = getelementptr inbounds %OoResS, ptr %v_res, i32 0, i32 1, !dbg !DILocation(line: 1, column: 1, scope: !72)
  %t8 = load { ptr, i64 }, ptr %t7, align 8, !dbg !DILocation(line: 1, column: 1, scope: !72)
  store { ptr, i64 } %t8, ptr %v_msg_4, align 8, !dbg !DILocation(line: 1, column: 1, scope: !72)
  %t10 = load { ptr, i64 }, ptr %v_msg_4, align 8, !dbg !DILocation(line: 1, column: 1, scope: !72)
  call void @oo_str_retain({ ptr, i64 } %t10), !dbg !DILocation(line: 1, column: 1, scope: !72)
  %t11 = load { ptr, i64 }, ptr %v_msg_4, align 8, !dbg !DILocation(line: 1, column: 1, scope: !72)
  call void @oo_str_release({ ptr, i64 } %t11), !dbg !DILocation(line: 1, column: 1, scope: !72)
  %t12 = load { ptr, i64 }, ptr %v_msg_4, align 8, !dbg !DILocation(line: 1, column: 1, scope: !72)
  call void @llvm.lifetime.end.p0(i64 24, ptr %v_res), !dbg !DILocation(line: 1, column: 1, scope: !72)
  call void @llvm.lifetime.end.p0(i64 16, ptr %v_msg_4), !dbg !DILocation(line: 1, column: 1, scope: !72)
  call void @llvm.lifetime.end.p0(i64 16, ptr %v_err_4), !dbg !DILocation(line: 1, column: 1, scope: !72)
  ret { ptr, i64 } %t12, !dbg !DILocation(line: 1, column: 1, scope: !72)
marm24:
  %t13 = getelementptr inbounds %OoResS, ptr %v_res, i32 0, i32 1, !dbg !DILocation(line: 1, column: 1, scope: !72)
  %t14 = load { ptr, i64 }, ptr %t13, align 8, !dbg !DILocation(line: 1, column: 1, scope: !72)
  store { ptr, i64 } %t14, ptr %v_err_4, align 8, !dbg !DILocation(line: 1, column: 1, scope: !72)
  %t16 = load { ptr, i64 }, ptr %v_err_4, align 8, !dbg !DILocation(line: 1, column: 1, scope: !72)
  call void @oo_str_retain({ ptr, i64 } %t16), !dbg !DILocation(line: 1, column: 1, scope: !72)
  %t17 = load { ptr, i64 }, ptr %v_err_4, align 8, !dbg !DILocation(line: 1, column: 1, scope: !72)
  call void @oo_str_release({ ptr, i64 } %t17), !dbg !DILocation(line: 1, column: 1, scope: !72)
  %t18 = load { ptr, i64 }, ptr %v_err_4, align 8, !dbg !DILocation(line: 1, column: 1, scope: !72)
  call void @llvm.lifetime.end.p0(i64 24, ptr %v_res), !dbg !DILocation(line: 1, column: 1, scope: !72)
  call void @llvm.lifetime.end.p0(i64 16, ptr %v_msg_4), !dbg !DILocation(line: 1, column: 1, scope: !72)
  call void @llvm.lifetime.end.p0(i64 16, ptr %v_err_4), !dbg !DILocation(line: 1, column: 1, scope: !72)
  ret { ptr, i64 } %t18, !dbg !DILocation(line: 1, column: 1, scope: !72)
mend4:
  unreachable, !dbg !DILocation(line: 1, column: 1, scope: !72)
}
!113 = distinct !DISubprogram(name: "make_item", scope: !11, file: !11, line: 93, type: !13, spFlags: DISPFlagDefinition, unit: !10)
; FN make_item
define hidden void @make_item(ptr noalias sret(%St_Item) align 8 %ret, i64 noundef %p_id, { ptr, i64 } %p_name) nounwind !dbg !113 {
  %v_id = alloca i64, align 8
  %v_name = alloca %OoStr, align 8
  %a3 = alloca %St_Item, align 8
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_id), !dbg !DILocation(line: 1, column: 1, scope: !113)
  call void @llvm.lifetime.start.p0(i64 16, ptr %v_name), !dbg !DILocation(line: 1, column: 1, scope: !113)
  call void @llvm.lifetime.start.p0(i64 -1, ptr %a3), !dbg !DILocation(line: 1, column: 1, scope: !113)
  store i64 %p_id, ptr %v_id, align 8, !dbg !DILocation(line: 1, column: 1, scope: !113)
  store { ptr, i64 } %p_name, ptr %v_name, align 8, !dbg !DILocation(line: 1, column: 1, scope: !113)
  %t4 = load i64, ptr %v_id, align 8, !dbg !DILocation(line: 1, column: 1, scope: !113)
  %t5 = getelementptr inbounds %St_Item, ptr %a3, i32 0, i32 0, !dbg !DILocation(line: 1, column: 1, scope: !113)
  store i64 %t4, ptr %t5, align 8, !dbg !DILocation(line: 1, column: 1, scope: !113)
  %t6 = getelementptr inbounds %St_Item, ptr %a3, i32 0, i32 1, !dbg !DILocation(line: 1, column: 1, scope: !113)
  %t7 = load { ptr, i64 }, ptr %v_name, align 8, !dbg !DILocation(line: 1, column: 1, scope: !113)
  store { ptr, i64 } %t7, ptr %t6, align 8, !dbg !DILocation(line: 1, column: 1, scope: !113)
  call void @oo_retain_St_Item(ptr %a3), !dbg !DILocation(line: 1, column: 1, scope: !113)
  %t8 = load %St_Item, ptr %a3, align 8, !dbg !DILocation(line: 1, column: 1, scope: !113)
  store %St_Item %t8, ptr %ret, align 8, !dbg !DILocation(line: 1, column: 1, scope: !113)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_id), !dbg !DILocation(line: 1, column: 1, scope: !113)
  call void @llvm.lifetime.end.p0(i64 16, ptr %v_name), !dbg !DILocation(line: 1, column: 1, scope: !113)
  call void @llvm.lifetime.end.p0(i64 -1, ptr %a3), !dbg !DILocation(line: 1, column: 1, scope: !113)
  ret void, !dbg !DILocation(line: 1, column: 1, scope: !113)
}
!141 = distinct !DISubprogram(name: "main", scope: !11, file: !11, line: 121, type: !13, spFlags: DISPFlagDefinition, unit: !10)
; FN main
@.s164 = private unnamed_addr constant [8 x i8] c"success\00"
define hidden i32 @main(i32 noundef %argc, ptr nocapture noundef %argv) nounwind !dbg !141 {
entry:
  %a12 = alloca %OoOptI, align 8
  %v_o_s130 = alloca %OoOptI, align 8
  %v_v_s143 = alloca i64, align 8
  %a18 = alloca %OoStr, align 8
  %a20 = alloca %OoResS, align 8
  %v_r_s153 = alloca %OoResS, align 8
  %v_msg_s168 = alloca %OoStr, align 8
  %a29 = alloca %St_Item, align 8
  %v_it_s178 = alloca %St_Item, align 8
  call void @llvm.lifetime.start.p0(i64 16, ptr %a12), !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @llvm.lifetime.start.p0(i64 16, ptr %v_o_s130), !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @llvm.lifetime.start.p0(i64 8, ptr %v_v_s143), !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @llvm.lifetime.start.p0(i64 16, ptr %a18), !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @llvm.lifetime.start.p0(i64 24, ptr %a20), !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @llvm.lifetime.start.p0(i64 24, ptr %v_r_s153), !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @llvm.lifetime.start.p0(i64 16, ptr %v_msg_s168), !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @llvm.lifetime.start.p0(i64 -1, ptr %a29), !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @llvm.lifetime.start.p0(i64 -1, ptr %v_it_s178), !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t13 = insertvalue %OoOptI { i32 1, i64 0 }, i64 42, 1, !dbg !DILocation(line: 1, column: 1, scope: !141)
  store %OoOptI %t13, ptr %a12, align 8, !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t14 = load %OoOptI, ptr %a12, align 8, !dbg !DILocation(line: 1, column: 1, scope: !141)
  store %OoOptI %t14, ptr %v_o_s130, align 8, !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t15 = call i64 @check_opt(ptr noalias nocapture byval(%OoOptI) align 8 %v_o_s130), !dbg !DILocation(line: 1, column: 1, scope: !141)
  store i64 %t15, ptr %v_v_s143, align 8, !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t16 = getelementptr inbounds [8 x i8], ptr @.s164, i64 0, i64 0, !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t17 = call { ptr, i64 } @oo_str_lit(ptr %t16), !dbg !DILocation(line: 1, column: 1, scope: !141)
  store { ptr, i64 } %t17, ptr %a18, align 8, !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t19 = load { ptr, i64 }, ptr %a18, align 8, !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t20 = extractvalue { ptr, i64 } %t19, 0, !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t21 = extractvalue { ptr, i64 } %t19, 1, !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t22 = insertvalue %OoStr { ptr null, i64 0 }, ptr %t20, 0, !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t23 = insertvalue %OoStr %t22, i64 %t21, 1, !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t24 = insertvalue %OoResS { i32 1, %OoStr { ptr null, i64 0 } }, %OoStr %t23, 1, !dbg !DILocation(line: 1, column: 1, scope: !141)
  store %OoResS %t24, ptr %a20, align 8, !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t25 = load %OoResS, ptr %a20, align 8, !dbg !DILocation(line: 1, column: 1, scope: !141)
  store %OoResS %t25, ptr %v_r_s153, align 8, !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t26 = call { ptr, i64 } @check_res(ptr noalias nocapture byval(%OoResS) align 8 %v_r_s153), !dbg !DILocation(line: 1, column: 1, scope: !141)
  store { ptr, i64 } %t26, ptr %v_msg_s168, align 8, !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t28 = load { ptr, i64 }, ptr %v_msg_s168, align 8, !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @make_item(ptr sret(%St_Item) align 8 %a29, i64 1, { ptr, i64 } %t28), !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t30 = load %St_Item, ptr %a29, align 8, !dbg !DILocation(line: 1, column: 1, scope: !141)
  store %St_Item %t30, ptr %v_it_s178, align 8, !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t31 = load i64, ptr %v_v_s143, align 8, !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t33 = icmp eq i64 %t31, 42, !dbg !DILocation(line: 1, column: 1, scope: !141)
  br i1 %t33, label %ar33, label %af33, !dbg !DILocation(line: 1, column: 1, scope: !141)
ar33:
  %t34 = getelementptr inbounds %St_Item, ptr %v_it_s178, i32 0, i32 0, !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t35 = load i64, ptr %t34, align 8, !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t37 = icmp eq i64 %t35, 1, !dbg !DILocation(line: 1, column: 1, scope: !141)
  br label %aj33, !dbg !DILocation(line: 1, column: 1, scope: !141)
aj33:
  br label %ae33, !dbg !DILocation(line: 1, column: 1, scope: !141)
af33:
  br label %ae33, !dbg !DILocation(line: 1, column: 1, scope: !141)
ae33:
  %t38 = phi i1 [ %t37, %aj33 ], [ false, %af33 ], !dbg !DILocation(line: 1, column: 1, scope: !141)
  br i1 %t38, label %then38, label %else38, !dbg !DILocation(line: 1, column: 1, scope: !141)
then38:
  call void @oo_release_St_Item(ptr %v_it_s178), !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t40 = load { ptr, i64 }, ptr %v_msg_s168, align 8, !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @oo_str_release({ ptr, i64 } %t40), !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t41 = getelementptr inbounds %OoResS, ptr %v_r_s153, i32 0, i32 0, !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t42 = load i32, ptr %t41, align 4, !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t43 = icmp ne i32 %t42, 0, !dbg !DILocation(line: 1, column: 1, scope: !141)
  br i1 %t43, label %arcy41, label %arcn41, !dbg !DILocation(line: 1, column: 1, scope: !141)
arcy41:
  %t44 = getelementptr inbounds %OoResS, ptr %v_r_s153, i32 0, i32 1, !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t45 = load { ptr, i64 }, ptr %t44, align 8, !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @oo_str_release({ ptr, i64 } %t45), !dbg !DILocation(line: 1, column: 1, scope: !141)
  br label %arcn41, !dbg !DILocation(line: 1, column: 1, scope: !141)
arcn41:
  call void @llvm.lifetime.end.p0(i64 16, ptr %a12), !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @llvm.lifetime.end.p0(i64 16, ptr %v_o_s130), !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_v_s143), !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @llvm.lifetime.end.p0(i64 16, ptr %a18), !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @llvm.lifetime.end.p0(i64 24, ptr %a20), !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @llvm.lifetime.end.p0(i64 24, ptr %v_r_s153), !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @llvm.lifetime.end.p0(i64 16, ptr %v_msg_s168), !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @llvm.lifetime.end.p0(i64 -1, ptr %a29), !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @llvm.lifetime.end.p0(i64 -1, ptr %v_it_s178), !dbg !DILocation(line: 1, column: 1, scope: !141)
  ret i32 0, !dbg !DILocation(line: 1, column: 1, scope: !141)
else38:
  br label %end38, !dbg !DILocation(line: 1, column: 1, scope: !141)
end38:
  call void @oo_release_St_Item(ptr %v_it_s178), !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t47 = load { ptr, i64 }, ptr %v_msg_s168, align 8, !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @oo_str_release({ ptr, i64 } %t47), !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t48 = getelementptr inbounds %OoResS, ptr %v_r_s153, i32 0, i32 0, !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t49 = load i32, ptr %t48, align 4, !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t50 = icmp ne i32 %t49, 0, !dbg !DILocation(line: 1, column: 1, scope: !141)
  br i1 %t50, label %arcy48, label %arcn48, !dbg !DILocation(line: 1, column: 1, scope: !141)
arcy48:
  %t51 = getelementptr inbounds %OoResS, ptr %v_r_s153, i32 0, i32 1, !dbg !DILocation(line: 1, column: 1, scope: !141)
  %t52 = load { ptr, i64 }, ptr %t51, align 8, !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @oo_str_release({ ptr, i64 } %t52), !dbg !DILocation(line: 1, column: 1, scope: !141)
  br label %arcn48, !dbg !DILocation(line: 1, column: 1, scope: !141)
arcn48:
  call void @llvm.lifetime.end.p0(i64 16, ptr %a12), !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @llvm.lifetime.end.p0(i64 16, ptr %v_o_s130), !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @llvm.lifetime.end.p0(i64 8, ptr %v_v_s143), !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @llvm.lifetime.end.p0(i64 16, ptr %a18), !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @llvm.lifetime.end.p0(i64 24, ptr %a20), !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @llvm.lifetime.end.p0(i64 24, ptr %v_r_s153), !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @llvm.lifetime.end.p0(i64 16, ptr %v_msg_s168), !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @llvm.lifetime.end.p0(i64 -1, ptr %a29), !dbg !DILocation(line: 1, column: 1, scope: !141)
  call void @llvm.lifetime.end.p0(i64 -1, ptr %v_it_s178), !dbg !DILocation(line: 1, column: 1, scope: !141)
  ret i32 0, !dbg !DILocation(line: 1, column: 1, scope: !141)
}
