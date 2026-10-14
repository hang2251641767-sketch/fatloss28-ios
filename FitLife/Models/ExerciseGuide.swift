import Foundation

enum ExerciseMovement: Equatable { case squat, hinge, chestPress, pushup, wallPushup, row, press, curl, raise, triceps, bridge, plank, sidePlank, deadBug, birdDog, lunge, calf, walk, stretch, checklist, custom }
struct ExerciseGuide {
    var movement: ExerciseMovement
    var cues: [String]
    static func forName(_ name: String) -> ExerciseGuide {
        let rules: [(String, ExerciseMovement, [String])] = [
            ("侧平板", .sidePlank, ["肘位于肩下", "髋保持稳定", "每侧分别完成"]),
            ("平板支撑", .plank, ["肘在肩下，收紧躯干", "臀部不要塌下或过度抬高", "保持呼吸"]),
            ("死虫", .deadBug, ["腰背自然稳定", "对侧手脚慢速伸展", "每侧分别完成"]),
            ("鸟狗", .birdDog, ["双手双膝支撑", "对侧手脚伸展", "躯干不要转动"]),
            ("臀桥", .bridge, ["脚掌稳定踩地", "用臀部发力抬髋", "不要过度反弓腰部"]),
            ("卧推", .chestPress, ["肩背稳定贴靠支撑面", "手腕保持稳定", "缓慢下放，不弹起重量"]),
            ("胸推", .chestPress, ["调整座位让手柄在胸部附近", "控制推起和回程", "不用冲击力"]),
            ("划船", .row, ["保持躯干稳定", "肘向身体后方移动", "控制还原，不耸肩"]),
            ("下拉", .row, ["坐稳并固定腿部", "向上胸部方向拉", "不要用身体后摆借力"]),
            ("侧平举", .raise, ["轻重量开始", "肘微屈，不耸肩", "抬到舒适高度"]),
            ("臂屈伸", .triceps, ["上臂尽量稳定", "用肘关节屈伸", "避开疼痛活动范围"]),
            ("下压", .triceps, ["肘靠近身体", "缓慢伸肘和回程", "躯干不要晃动"]),
            ("弯举", .curl, ["上臂稳定", "手腕保持自然", "不用身体摆动借力"]),
            ("推举", .press, ["躯干稳定", "控制向上推起", "不要过度挺腰"]),
            ("肩推", .press, ["调整器械座位", "在舒适范围推起", "保持躯干稳定"]),
            ("硬拉", .hinge, ["从髋部向后折叠", "脊柱保持自然", "重量靠近身体"]),
            ("弓步", .lunge, ["向后迈步，保持平衡", "膝与脚尖方向一致", "每侧分别完成"]),
            ("坐站", .squat, ["使用稳固椅子", "脚掌踩稳", "慢坐慢站"]),
            ("深蹲", .squat, ["脚掌稳定踩地", "膝随脚尖方向移动", "只下蹲到可控深度"]),
            ("半蹲", .squat, ["用稳固支撑辅助平衡", "动作慢而可控", "膝随脚尖方向"]),
            ("腿举", .squat, ["先调整器械", "膝随脚尖方向", "不要弹起或锁死膝盖"]),
            ("腿屈伸", .calf, ["调整座位与转轴", "缓慢伸膝", "避免冲击和疼痛范围"]),
            ("腿弯举", .hinge, ["调整器械支撑", "缓慢屈膝", "保持身体稳定"]),
            ("墙壁俯卧撑", .wallPushup, ["用稳固墙面支撑", "躯干保持直线", "控制下降和推起"]),
            ("俯卧撑", .pushup, ["选择稳固墙面或高位支撑", "躯干保持直线", "控制下降和推起"]),
            ("提踵", .calf, ["扶稳支撑", "慢慢抬起脚跟", "控制回到地面"]),
            ("起身", .checklist, ["起身活动一会儿", "轻松走动", "避免长时间连续久坐"]),
            ("拉伸", .stretch, ["自然呼吸", "只到轻柔牵拉感", "不要拉到疼痛"]),
            ("活动", .stretch, ["慢速轻柔活动", "保持舒适范围", "不要憋气"]),
            ("步", .walk, ["保持轻松至中等节奏", "能说完整句子", "可按需要降低速度"]),
            ("散步", .walk, ["轻松自然走动", "呼吸舒适", "保持稳定步伐"])
        ]
        if let rule = rules.first(where: { name.contains($0.0) }) {
            let needsEquipmentSpecificDemo = ["器械", "高位下拉", "坐姿划船", "腿举", "腿屈伸", "腿弯举", "绳索下压", "高位支撑俯卧撑"].contains { name.contains($0) }
            return ExerciseGuide(movement: needsEquipmentSpecificDemo ? .custom : rule.1, cues: rule.2)
        }
        return ExerciseGuide(movement: .custom, cues: ["按你熟悉的标准动作完成", "控制节奏和重量", "此自定义动作暂无对应示意"])
    }
}
