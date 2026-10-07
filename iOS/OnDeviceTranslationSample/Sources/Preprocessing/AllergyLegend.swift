import Foundation

/// Pre-translated legend of the 19 allergens used in Korean school meal notices.
/// Machine translation gets these wrong (e.g. 난류 "eggs" → "turbulence"), so they are never sent to an engine.
/// Translations follow common food-allergen labeling terms and should be checked by native speakers before release.
enum AllergyLegend {
    static func text(for target: TargetLanguage) -> String {
        switch target {
        case .english:
            return """
            Allergy information
            1.Eggs 2.Milk 3.Buckwheat 4.Peanuts 5.Soybeans 6.Wheat 7.Mackerel 8.Crab 9.Shrimp 10.Pork 11.Peach 12.Tomato 13.Sulfites 14.Walnuts 15.Chicken 16.Beef 17.Squid 18.Shellfish (including oysters, abalone, mussels) 19.Pine nuts
            """
        case .vietnamese:
            return """
            Thông tin dị ứng
            1.Trứng 2.Sữa 3.Kiều mạch 4.Đậu phộng 5.Đậu nành 6.Lúa mì 7.Cá thu 8.Cua 9.Tôm 10.Thịt lợn 11.Đào 12.Cà chua 13.Sulfit 14.Quả óc chó 15.Thịt gà 16.Thịt bò 17.Mực 18.Động vật có vỏ (gồm hàu, bào ngư, vẹm) 19.Hạt thông
            """
        case .indonesian:
            return """
            Informasi alergi
            1.Telur 2.Susu 3.Soba (buckwheat) 4.Kacang tanah 5.Kedelai 6.Gandum 7.Ikan makarel 8.Kepiting 9.Udang 10.Daging babi 11.Persik 12.Tomat 13.Sulfit 14.Kenari 15.Daging ayam 16.Daging sapi 17.Cumi-cumi 18.Kerang-kerangan (termasuk tiram, abalon, kerang hijau) 19.Kacang pinus
            """
        case .japanese:
            return """
            アレルギー情報
            1.卵 2.乳 3.そば 4.落花生 5.大豆 6.小麦 7.さば 8.かに 9.えび 10.豚肉 11.もも 12.トマト 13.亜硫酸塩 14.くるみ 15.鶏肉 16.牛肉 17.いか 18.貝類（かき・あわび・ムール貝を含む） 19.松の実
            """
        case .chineseSimplified:
            return """
            过敏原信息
            1.鸡蛋 2.牛奶 3.荞麦 4.花生 5.大豆 6.小麦 7.鲭鱼 8.蟹 9.虾 10.猪肉 11.桃 12.番茄 13.亚硫酸盐 14.核桃 15.鸡肉 16.牛肉 17.鱿鱼 18.贝类（包括牡蛎、鲍鱼、贻贝） 19.松子
            """
        }
    }
}
