-- Lucky's Wardrobe: Raid tier tokens, from the client's own tables at build
-- 12.1.5.70077, generated 2026-10-20 by tokens.py; do not edit by hand.
--
-- slot is the Enum.InventoryType the token makes, 0 for a token that makes any.
-- classMask is the classes it serves. instances and encounters are the journal
-- instances and bosses that drop it.
LuckysWardrobe = LuckysWardrobe or {}

LuckysWardrobe.TierTokensData = {
    [20927] = { slot = 7, classMask = 153, instances = { 744 }, encounters = { 1550 } }, -- Ouro's Intact Hide
    [20928] = { slot = 9, classMask = 29, instances = { 744 }, encounters = { 1546, 1548 } }, -- Qiraji Bindings of Command
    [20929] = { slot = 5, classMask = 79, instances = { 744 }, encounters = { 1551 } }, -- Carapace of the Old God
    [20930] = { slot = 1, classMask = 1102, instances = { 744 }, encounters = { 1549 } }, -- Vek'lor's Diadem
    [20931] = { slot = 7, classMask = 1350, instances = { 744 }, encounters = { 1550 } }, -- Skin of the Great Sandworm
    [20932] = { slot = 9, classMask = 1474, instances = { 744 }, encounters = { 1546, 1548 } }, -- Qiraji Bindings of Dominance
    [20933] = { slot = 5, classMask = 1424, instances = { 744 }, encounters = { 1551 } }, -- Husk of the Old God
    [29753] = { slot = 5, classMask = 1041, instances = { 747 }, encounters = { 1566 } }, -- Chestguard of the Fallen Defender
    [29754] = { slot = 5, classMask = 74, instances = { 747 }, encounters = { 1566 } }, -- Chestguard of the Fallen Champion
    [29755] = { slot = 5, classMask = 388, instances = { 747 }, encounters = { 1566 } }, -- Chestguard of the Fallen Hero
    [29756] = { slot = 10, classMask = 388, instances = { 745 }, encounters = { 1557 } }, -- Gloves of the Fallen Hero
    [29757] = { slot = 10, classMask = 74, instances = { 745 }, encounters = { 1557 } }, -- Gloves of the Fallen Champion
    [29758] = { slot = 10, classMask = 1041, instances = { 745 }, encounters = { 1557 } }, -- Gloves of the Fallen Defender
    [29759] = { slot = 1, classMask = 388, instances = { 745 }, encounters = { 1563 } }, -- Helm of the Fallen Hero
    [29760] = { slot = 1, classMask = 74, instances = { 745 }, encounters = { 1563 } }, -- Helm of the Fallen Champion
    [29761] = { slot = 1, classMask = 1041, instances = { 745 }, encounters = { 1563 } }, -- Helm of the Fallen Defender
    [29762] = { slot = 3, classMask = 388, instances = { 746 }, encounters = { 1564 } }, -- Pauldrons of the Fallen Hero
    [29763] = { slot = 3, classMask = 74, instances = { 746 }, encounters = { 1564 } }, -- Pauldrons of the Fallen Champion
    [29764] = { slot = 3, classMask = 1041, instances = { 746 }, encounters = { 1564 } }, -- Pauldrons of the Fallen Defender
    [29765] = { slot = 7, classMask = 388, instances = { 746 }, encounters = { 1565 } }, -- Leggings of the Fallen Hero
    [29766] = { slot = 7, classMask = 74, instances = { 746 }, encounters = { 1565 } }, -- Leggings of the Fallen Champion
    [29767] = { slot = 7, classMask = 1041, instances = { 746 }, encounters = { 1565 } }, -- Leggings of the Fallen Defender
    [30236] = { slot = 5, classMask = 74, instances = { 749 }, encounters = { 1576 } }, -- Chestguard of the Vanquished Champion
    [30237] = { slot = 5, classMask = 1041, instances = { 749 }, encounters = { 1576 } }, -- Chestguard of the Vanquished Defender
    [30238] = { slot = 5, classMask = 388, instances = { 749 }, encounters = { 1576 } }, -- Chestguard of the Vanquished Hero
    [30239] = { slot = 10, classMask = 74, instances = { 748 }, encounters = { 1569 } }, -- Gloves of the Vanquished Champion
    [30240] = { slot = 10, classMask = 1041, instances = { 748 }, encounters = { 1569 } }, -- Gloves of the Vanquished Defender
    [30241] = { slot = 10, classMask = 388, instances = { 748 }, encounters = { 1569 } }, -- Gloves of the Vanquished Hero
    [30242] = { slot = 1, classMask = 74, instances = { 748 }, encounters = { 1572 } }, -- Helm of the Vanquished Champion
    [30243] = { slot = 1, classMask = 1041, instances = { 748 }, encounters = { 1572 } }, -- Helm of the Vanquished Defender
    [30244] = { slot = 1, classMask = 388, instances = { 748 }, encounters = { 1572 } }, -- Helm of the Vanquished Hero
    [30245] = { slot = 7, classMask = 74, instances = { 748 }, encounters = { 1570 } }, -- Leggings of the Vanquished Champion
    [30246] = { slot = 7, classMask = 1041, instances = { 748 }, encounters = { 1570 } }, -- Leggings of the Vanquished Defender
    [30247] = { slot = 7, classMask = 388, instances = { 748 }, encounters = { 1570 } }, -- Leggings of the Vanquished Hero
    [30248] = { slot = 3, classMask = 74, instances = { 749 }, encounters = { 1574 } }, -- Pauldrons of the Vanquished Champion
    [30249] = { slot = 3, classMask = 1041, instances = { 749 }, encounters = { 1574 } }, -- Pauldrons of the Vanquished Defender
    [30250] = { slot = 3, classMask = 388, instances = { 749 }, encounters = { 1574 } }, -- Pauldrons of the Vanquished Hero
    [31089] = { slot = 5, classMask = 274, instances = { 751 }, encounters = { 1590 } }, -- Chestguard of the Forgotten Conqueror
    [31090] = { slot = 5, classMask = 1160, instances = { 751 }, encounters = { 1590 } }, -- Chestguard of the Forgotten Vanquisher
    [31091] = { slot = 5, classMask = 69, instances = { 751 }, encounters = { 1590 } }, -- Chestguard of the Forgotten Protector
    [31092] = { slot = 10, classMask = 274, instances = { 750 }, encounters = { 1580 } }, -- Gloves of the Forgotten Conqueror
    [31093] = { slot = 10, classMask = 1160, instances = { 750 }, encounters = { 1580 } }, -- Gloves of the Forgotten Vanquisher
    [31094] = { slot = 10, classMask = 69, instances = { 750 }, encounters = { 1580 } }, -- Gloves of the Forgotten Protector
    [31095] = { slot = 1, classMask = 69, instances = { 750 }, encounters = { 1581 } }, -- Helm of the Forgotten Protector
    [31096] = { slot = 1, classMask = 1160, instances = { 750 }, encounters = { 1581 } }, -- Helm of the Forgotten Vanquisher
    [31097] = { slot = 1, classMask = 274, instances = { 750 }, encounters = { 1581 } }, -- Helm of the Forgotten Conqueror
    [31098] = { slot = 7, classMask = 274, instances = { 751 }, encounters = { 1589 } }, -- Leggings of the Forgotten Conqueror
    [31099] = { slot = 7, classMask = 1160, instances = { 751 }, encounters = { 1589 } }, -- Leggings of the Forgotten Vanquisher
    [31100] = { slot = 7, classMask = 69, instances = { 751 }, encounters = { 1589 } }, -- Leggings of the Forgotten Protector
    [31101] = { slot = 3, classMask = 274, instances = { 751 }, encounters = { 1588 } }, -- Pauldrons of the Forgotten Conqueror
    [31102] = { slot = 3, classMask = 1160, instances = { 751 }, encounters = { 1588 } }, -- Pauldrons of the Forgotten Vanquisher
    [31103] = { slot = 3, classMask = 69, instances = { 751 }, encounters = { 1588 } }, -- Pauldrons of the Forgotten Protector
    [34848] = { slot = 9, classMask = 274, instances = { 752 }, encounters = { 1591, 1594 } }, -- Bracers of the Forgotten Conqueror
    [34851] = { slot = 9, classMask = 69, instances = { 752 }, encounters = { 1591, 1594 } }, -- Bracers of the Forgotten Protector
    [34852] = { slot = 9, classMask = 1160, instances = { 752 }, encounters = { 1591, 1594 } }, -- Bracers of the Forgotten Vanquisher
    [34853] = { slot = 6, classMask = 274, instances = { 752 }, encounters = { 1592, 1594 } }, -- Belt of the Forgotten Conqueror
    [34854] = { slot = 6, classMask = 69, instances = { 752 }, encounters = { 1592, 1594 } }, -- Belt of the Forgotten Protector
    [34855] = { slot = 6, classMask = 1160, instances = { 752 }, encounters = { 1592, 1594 } }, -- Belt of the Forgotten Vanquisher
    [34856] = { slot = 8, classMask = 274, instances = { 752 }, encounters = { 1593, 1594 } }, -- Boots of the Forgotten Conqueror
    [34857] = { slot = 8, classMask = 69, instances = { 752 }, encounters = { 1593, 1594 } }, -- Boots of the Forgotten Protector
    [34858] = { slot = 8, classMask = 1160, instances = { 752 }, encounters = { 1593, 1594 } }, -- Boots of the Forgotten Vanquisher
    [40610] = { slot = 5, classMask = 274, instances = { 754 }, encounters = { 1609, 1612 } }, -- Chestguard of the Lost Conqueror
    [40611] = { slot = 5, classMask = 69, instances = { 754 }, encounters = { 1609, 1612 } }, -- Chestguard of the Lost Protector
    [40612] = { slot = 5, classMask = 1192, instances = { 754 }, encounters = { 1609, 1612 } }, -- Chestguard of the Lost Vanquisher
    [40613] = { slot = 10, classMask = 274, instances = { 755 }, encounters = { 1616 } }, -- Gloves of the Lost Conqueror
    [40614] = { slot = 10, classMask = 69, instances = { 755 }, encounters = { 1616 } }, -- Gloves of the Lost Protector
    [40615] = { slot = 10, classMask = 1192, instances = { 755 }, encounters = { 1616 } }, -- Gloves of the Lost Vanquisher
    [40616] = { slot = 1, classMask = 274, instances = { 754 }, encounters = { 1615 } }, -- Helm of the Lost Conqueror
    [40617] = { slot = 1, classMask = 69, instances = { 754 }, encounters = { 1615 } }, -- Helm of the Lost Protector
    [40618] = { slot = 1, classMask = 1192, instances = { 754 }, encounters = { 1615 } }, -- Helm of the Lost Vanquisher
    [40619] = { slot = 7, classMask = 274, instances = { 754 }, encounters = { 1612, 1613 } }, -- Leggings of the Lost Conqueror
    [40620] = { slot = 7, classMask = 69, instances = { 754 }, encounters = { 1612, 1613 } }, -- Leggings of the Lost Protector
    [40621] = { slot = 7, classMask = 1192, instances = { 754 }, encounters = { 1612, 1613 } }, -- Leggings of the Lost Vanquisher
    [40622] = { slot = 3, classMask = 274, instances = { 754 }, encounters = { 1606, 1612 } }, -- Spaulders of the Lost Conqueror
    [40623] = { slot = 3, classMask = 69, instances = { 754 }, encounters = { 1606, 1612 } }, -- Spaulders of the Lost Protector
    [40624] = { slot = 3, classMask = 1192, instances = { 754 }, encounters = { 1606, 1612 } }, -- Spaulders of the Lost Vanquisher
    [40625] = { slot = 5, classMask = 274, instances = { 754 }, encounters = { 1609, 1612 } }, -- Breastplate of the Lost Conqueror
    [40626] = { slot = 5, classMask = 69, instances = { 754 }, encounters = { 1609, 1612 } }, -- Breastplate of the Lost Protector
    [40627] = { slot = 5, classMask = 1192, instances = { 754 }, encounters = { 1609, 1612 } }, -- Breastplate of the Lost Vanquisher
    [40628] = { slot = 10, classMask = 274, instances = { 755 }, encounters = { 1616 } }, -- Gauntlets of the Lost Conqueror
    [40629] = { slot = 10, classMask = 69, instances = { 755 }, encounters = { 1616 } }, -- Gauntlets of the Lost Protector
    [40630] = { slot = 10, classMask = 1192, instances = { 755 }, encounters = { 1616 } }, -- Gauntlets of the Lost Vanquisher
    [40631] = { slot = 1, classMask = 274, instances = { 754 }, encounters = { 1615 } }, -- Crown of the Lost Conqueror
    [40632] = { slot = 1, classMask = 69, instances = { 754 }, encounters = { 1615 } }, -- Crown of the Lost Protector
    [40633] = { slot = 1, classMask = 1192, instances = { 754 }, encounters = { 1615 } }, -- Crown of the Lost Vanquisher
    [40634] = { slot = 7, classMask = 274, instances = { 754 }, encounters = { 1612, 1613 } }, -- Legplates of the Lost Conqueror
    [40635] = { slot = 7, classMask = 69, instances = { 754 }, encounters = { 1612, 1613 } }, -- Legplates of the Lost Protector
    [40636] = { slot = 7, classMask = 1192, instances = { 754 }, encounters = { 1612, 1613 } }, -- Legplates of the Lost Vanquisher
    [40637] = { slot = 3, classMask = 274, instances = { 754 }, encounters = { 1606, 1612 } }, -- Mantle of the Lost Conqueror
    [40638] = { slot = 3, classMask = 69, instances = { 754 }, encounters = { 1606, 1612 } }, -- Mantle of the Lost Protector
    [40639] = { slot = 3, classMask = 1192, instances = { 754 }, encounters = { 1606, 1612 } }, -- Mantle of the Lost Vanquisher
    [45632] = { slot = 5, classMask = 274, instances = { 759 }, encounters = { 1644 } }, -- Breastplate of the Wayward Conqueror
    [45633] = { slot = 5, classMask = 69, instances = { 759 }, encounters = { 1644 } }, -- Breastplate of the Wayward Protector
    [45634] = { slot = 5, classMask = 1192, instances = { 759 }, encounters = { 1644 } }, -- Breastplate of the Wayward Vanquisher
    [45635] = { slot = 5, classMask = 274, instances = { 759 }, encounters = { 1649 } }, -- Chestguard of the Wayward Conqueror
    [45636] = { slot = 5, classMask = 69, instances = { 759 }, encounters = { 1649 } }, -- Chestguard of the Wayward Protector
    [45637] = { slot = 5, classMask = 1192, instances = { 759 }, encounters = { 1649 } }, -- Chestguard of the Wayward Vanquisher
    [45638] = { slot = 1, classMask = 274, instances = { 759 }, encounters = { 1645 } }, -- Crown of the Wayward Conqueror
    [45639] = { slot = 1, classMask = 69, instances = { 759 }, encounters = { 1645 } }, -- Crown of the Wayward Protector
    [45640] = { slot = 1, classMask = 1192, instances = { 759 }, encounters = { 1645 } }, -- Crown of the Wayward Vanquisher
    [45641] = { slot = 10, classMask = 274, instances = { 759 }, encounters = { 1647 } }, -- Gauntlets of the Wayward Conqueror
    [45642] = { slot = 10, classMask = 69, instances = { 759 }, encounters = { 1647 } }, -- Gauntlets of the Wayward Protector
    [45643] = { slot = 10, classMask = 1192, instances = { 759 }, encounters = { 1647 } }, -- Gauntlets of the Wayward Vanquisher
    [45644] = { slot = 10, classMask = 274, instances = { 759 }, encounters = { 1646 } }, -- Gloves of the Wayward Conqueror
    [45645] = { slot = 10, classMask = 69, instances = { 759 }, encounters = { 1646 } }, -- Gloves of the Wayward Protector
    [45646] = { slot = 10, classMask = 1192, instances = { 759 }, encounters = { 1646 } }, -- Gloves of the Wayward Vanquisher
    [45647] = { slot = 1, classMask = 274, instances = { 759 }, encounters = { 1647 } }, -- Helm of the Wayward Conqueror
    [45648] = { slot = 1, classMask = 69, instances = { 759 }, encounters = { 1647 } }, -- Helm of the Wayward Protector
    [45649] = { slot = 1, classMask = 1192, instances = { 759 }, encounters = { 1647 } }, -- Helm of the Wayward Vanquisher
    [45650] = { slot = 7, classMask = 274, instances = { 759 }, encounters = { 1644 } }, -- Leggings of the Wayward Conqueror
    [45651] = { slot = 7, classMask = 69, instances = { 759 }, encounters = { 1644 } }, -- Leggings of the Wayward Protector
    [45652] = { slot = 7, classMask = 1192, instances = { 759 }, encounters = { 1644 } }, -- Leggings of the Wayward Vanquisher
    [45653] = { slot = 7, classMask = 274, instances = { 759 }, encounters = { 1646 } }, -- Legplates of the Wayward Conqueror
    [45654] = { slot = 7, classMask = 69, instances = { 759 }, encounters = { 1646 } }, -- Legplates of the Wayward Protector
    [45655] = { slot = 7, classMask = 1192, instances = { 759 }, encounters = { 1646 } }, -- Legplates of the Wayward Vanquisher
    [45656] = { slot = 3, classMask = 274, instances = { 759 }, encounters = { 1649 } }, -- Mantle of the Wayward Conqueror
    [45657] = { slot = 3, classMask = 69, instances = { 759 }, encounters = { 1649 } }, -- Mantle of the Wayward Protector
    [45658] = { slot = 3, classMask = 1192, instances = { 759 }, encounters = { 1649 } }, -- Mantle of the Wayward Vanquisher
    [45659] = { slot = 3, classMask = 274, instances = { 759 }, encounters = { 1645 } }, -- Spaulders of the Wayward Conqueror
    [45660] = { slot = 3, classMask = 69, instances = { 759 }, encounters = { 1645 } }, -- Spaulders of the Wayward Protector
    [45661] = { slot = 3, classMask = 1192, instances = { 759 }, encounters = { 1645 } }, -- Spaulders of the Wayward Vanquisher
    [52025] = { slot = 0, classMask = 1192, instances = { 758 }, encounters = { 1628, 1631, 1633, 1635, 1636 } }, -- Vanquisher's Mark of Sanctification
    [52026] = { slot = 0, classMask = 69, instances = { 758 }, encounters = { 1628, 1631, 1633, 1635, 1636 } }, -- Protector's Mark of Sanctification
    [52027] = { slot = 0, classMask = 274, instances = { 758 }, encounters = { 1628, 1631, 1633, 1635, 1636 } }, -- Conqueror's Mark of Sanctification
    [52028] = { slot = 0, classMask = 1192, instances = { 758 }, encounters = { 1628, 1631, 1633, 1635, 1636 } }, -- Vanquisher's Mark of Sanctification
    [52029] = { slot = 0, classMask = 69, instances = { 758 }, encounters = { 1628, 1631, 1633, 1635, 1636 } }, -- Protector's Mark of Sanctification
    [52030] = { slot = 0, classMask = 274, instances = { 758 }, encounters = { 1628, 1631, 1633, 1635, 1636 } }, -- Conqueror's Mark of Sanctification
    [63682] = { slot = 1, classMask = 1192, instances = { 73, 74 }, encounters = { 155, 174 } }, -- Helm of the Forlorn Vanquisher
    [63683] = { slot = 1, classMask = 274, instances = { 73, 74 }, encounters = { 155, 174 } }, -- Helm of the Forlorn Conqueror
    [63684] = { slot = 1, classMask = 69, instances = { 73, 74 }, encounters = { 155, 174 } }, -- Helm of the Forlorn Protector
    [64314] = { slot = 3, classMask = 1192, instances = { 72, 74 }, encounters = { 155, 167 } }, -- Mantle of the Forlorn Vanquisher
    [64315] = { slot = 3, classMask = 274, instances = { 72, 74 }, encounters = { 155, 167 } }, -- Mantle of the Forlorn Conqueror
    [64316] = { slot = 3, classMask = 69, instances = { 72, 74 }, encounters = { 155, 167 } }, -- Mantle of the Forlorn Protector
    [65000] = { slot = 1, classMask = 69, instances = { 73, 74 }, encounters = { 155, 174 } }, -- Crown of the Forlorn Protector
    [65001] = { slot = 1, classMask = 274, instances = { 73, 74 }, encounters = { 155, 174 } }, -- Crown of the Forlorn Conqueror
    [65002] = { slot = 1, classMask = 1192, instances = { 73, 74 }, encounters = { 155, 174 } }, -- Crown of the Forlorn Vanquisher
    [65087] = { slot = 3, classMask = 69, instances = { 72, 74 }, encounters = { 155, 167 } }, -- Shoulders of the Forlorn Protector
    [65088] = { slot = 3, classMask = 274, instances = { 72, 74 }, encounters = { 155, 167 } }, -- Shoulders of the Forlorn Conqueror
    [65089] = { slot = 3, classMask = 1192, instances = { 72, 74 }, encounters = { 155, 167 } }, -- Shoulders of the Forlorn Vanquisher
    [67423] = { slot = 5, classMask = 274, instances = { 72 }, encounters = { 156 } }, -- Chest of the Forlorn Conqueror
    [67424] = { slot = 5, classMask = 69, instances = { 72 }, encounters = { 156 } }, -- Chest of the Forlorn Protector
    [67425] = { slot = 5, classMask = 1192, instances = { 72 }, encounters = { 156 } }, -- Chest of the Forlorn Vanquisher
    [67426] = { slot = 7, classMask = 1192, instances = { 73 }, encounters = { 173 } }, -- Leggings of the Forlorn Vanquisher
    [67427] = { slot = 7, classMask = 69, instances = { 73 }, encounters = { 173 } }, -- Leggings of the Forlorn Protector
    [67428] = { slot = 7, classMask = 274, instances = { 73 }, encounters = { 173 } }, -- Leggings of the Forlorn Conqueror
    [67429] = { slot = 10, classMask = 274, instances = { 73 }, encounters = { 170 } }, -- Gauntlets of the Forlorn Conqueror
    [67430] = { slot = 10, classMask = 69, instances = { 73 }, encounters = { 170 } }, -- Gauntlets of the Forlorn Protector
    [67431] = { slot = 10, classMask = 1192, instances = { 73 }, encounters = { 170 } }, -- Gauntlets of the Forlorn Vanquisher
    [71668] = { slot = 1, classMask = 1192, instances = { 78 }, encounters = { 198 } }, -- Helm of the Fiery Vanquisher
    [71669] = { slot = 10, classMask = 1192, instances = { 78 }, encounters = { 196 } }, -- Gauntlets of the Fiery Vanquisher
    [71670] = { slot = 1, classMask = 1192, instances = { 78 }, encounters = { 198 } }, -- Crown of the Fiery Vanquisher
    [71671] = { slot = 7, classMask = 1192, instances = { 78 }, encounters = { 195 } }, -- Leggings of the Fiery Vanquisher
    [71672] = { slot = 5, classMask = 1192, instances = { 78 }, encounters = { 194 } }, -- Chest of the Fiery Vanquisher
    [71673] = { slot = 3, classMask = 1192, instances = { 78 }, encounters = { 197 } }, -- Shoulders of the Fiery Vanquisher
    [71674] = { slot = 3, classMask = 1192, instances = { 78 }, encounters = { 197 } }, -- Mantle of the Fiery Vanquisher
    [71675] = { slot = 1, classMask = 274, instances = { 78 }, encounters = { 198 } }, -- Helm of the Fiery Conqueror
    [71676] = { slot = 10, classMask = 274, instances = { 78 }, encounters = { 196 } }, -- Gauntlets of the Fiery Conqueror
    [71677] = { slot = 1, classMask = 274, instances = { 78 }, encounters = { 198 } }, -- Crown of the Fiery Conqueror
    [71678] = { slot = 7, classMask = 274, instances = { 78 }, encounters = { 195 } }, -- Leggings of the Fiery Conqueror
    [71679] = { slot = 5, classMask = 274, instances = { 78 }, encounters = { 194 } }, -- Chest of the Fiery Conqueror
    [71680] = { slot = 3, classMask = 274, instances = { 78 }, encounters = { 197 } }, -- Shoulders of the Fiery Conqueror
    [71681] = { slot = 3, classMask = 274, instances = { 78 }, encounters = { 197 } }, -- Mantle of the Fiery Conqueror
    [71682] = { slot = 1, classMask = 69, instances = { 78 }, encounters = { 198 } }, -- Helm of the Fiery Protector
    [71683] = { slot = 10, classMask = 69, instances = { 78 }, encounters = { 196 } }, -- Gauntlets of the Fiery Protector
    [71684] = { slot = 1, classMask = 69, instances = { 78 }, encounters = { 198 } }, -- Crown of the Fiery Protector
    [71685] = { slot = 7, classMask = 69, instances = { 78 }, encounters = { 195 } }, -- Leggings of the Fiery Protector
    [71686] = { slot = 5, classMask = 69, instances = { 78 }, encounters = { 194 } }, -- Chest of the Fiery Protector
    [71687] = { slot = 3, classMask = 69, instances = { 78 }, encounters = { 197 } }, -- Shoulders of the Fiery Protector
    [71688] = { slot = 3, classMask = 69, instances = { 78 }, encounters = { 197 } }, -- Mantle of the Fiery Protector
    [78170] = { slot = 3, classMask = 1192, instances = { 187 }, encounters = { 317 } }, -- Shoulders of the Corrupted Vanquisher
    [78171] = { slot = 7, classMask = 1192, instances = { 187 }, encounters = { 325 } }, -- Leggings of the Corrupted Vanquisher
    [78172] = { slot = 1, classMask = 1192, instances = { 187 }, encounters = { 332 } }, -- Crown of the Corrupted Vanquisher
    [78173] = { slot = 10, classMask = 1192, instances = { 187 }, encounters = { 324 } }, -- Gauntlets of the Corrupted Vanquisher
    [78174] = { slot = 5, classMask = 1192, instances = { 187 }, encounters = { 331 } }, -- Chest of the Corrupted Vanquisher
    [78175] = { slot = 3, classMask = 69, instances = { 187 }, encounters = { 317 } }, -- Shoulders of the Corrupted Protector
    [78176] = { slot = 7, classMask = 69, instances = { 187 }, encounters = { 325 } }, -- Leggings of the Corrupted Protector
    [78177] = { slot = 1, classMask = 69, instances = { 187 }, encounters = { 332 } }, -- Crown of the Corrupted Protector
    [78178] = { slot = 10, classMask = 69, instances = { 187 }, encounters = { 324 } }, -- Gauntlets of the Corrupted Protector
    [78179] = { slot = 5, classMask = 69, instances = { 187 }, encounters = { 331 } }, -- Chest of the Corrupted Protector
    [78180] = { slot = 3, classMask = 274, instances = { 187 }, encounters = { 317 } }, -- Shoulders of the Corrupted Conqueror
    [78181] = { slot = 7, classMask = 274, instances = { 187 }, encounters = { 325 } }, -- Leggings of the Corrupted Conqueror
    [78182] = { slot = 1, classMask = 274, instances = { 187 }, encounters = { 332 } }, -- Crown of the Corrupted Conqueror
    [78183] = { slot = 10, classMask = 274, instances = { 187 }, encounters = { 324 } }, -- Gauntlets of the Corrupted Conqueror
    [78184] = { slot = 5, classMask = 274, instances = { 187 }, encounters = { 331 } }, -- Chest of the Corrupted Conqueror
    [78847] = { slot = 5, classMask = 274, instances = { 187 }, encounters = { 331 } }, -- Chest of the Corrupted Conqueror
    [78848] = { slot = 5, classMask = 69, instances = { 187 }, encounters = { 331 } }, -- Chest of the Corrupted Protector
    [78849] = { slot = 5, classMask = 1192, instances = { 187 }, encounters = { 331 } }, -- Chest of the Corrupted Vanquisher
    [78850] = { slot = 1, classMask = 274, instances = { 187 }, encounters = { 332 } }, -- Crown of the Corrupted Conqueror
    [78851] = { slot = 1, classMask = 69, instances = { 187 }, encounters = { 332 } }, -- Crown of the Corrupted Protector
    [78852] = { slot = 1, classMask = 1192, instances = { 187 }, encounters = { 332 } }, -- Crown of the Corrupted Vanquisher
    [78853] = { slot = 10, classMask = 274, instances = { 187 }, encounters = { 324 } }, -- Gauntlets of the Corrupted Conqueror
    [78854] = { slot = 10, classMask = 69, instances = { 187 }, encounters = { 324 } }, -- Gauntlets of the Corrupted Protector
    [78855] = { slot = 10, classMask = 1192, instances = { 187 }, encounters = { 324 } }, -- Gauntlets of the Corrupted Vanquisher
    [78856] = { slot = 7, classMask = 274, instances = { 187 }, encounters = { 325 } }, -- Leggings of the Corrupted Conqueror
    [78857] = { slot = 7, classMask = 69, instances = { 187 }, encounters = { 325 } }, -- Leggings of the Corrupted Protector
    [78858] = { slot = 7, classMask = 1192, instances = { 187 }, encounters = { 325 } }, -- Leggings of the Corrupted Vanquisher
    [78859] = { slot = 3, classMask = 274, instances = { 187 }, encounters = { 317 } }, -- Shoulders of the Corrupted Conqueror
    [78860] = { slot = 3, classMask = 69, instances = { 187 }, encounters = { 317 } }, -- Shoulders of the Corrupted Protector
    [78861] = { slot = 3, classMask = 1192, instances = { 187 }, encounters = { 317 } }, -- Shoulders of the Corrupted Vanquisher
    [78862] = { slot = 5, classMask = 1192, instances = { 187 }, encounters = { 311, 317, 324, 325, 331, 332 } }, -- Chest of the Corrupted Vanquisher
    [78863] = { slot = 5, classMask = 274, instances = { 187 }, encounters = { 311, 317, 324, 325, 331, 332 } }, -- Chest of the Corrupted Conqueror
    [78864] = { slot = 5, classMask = 69, instances = { 187 }, encounters = { 311, 317, 324, 325, 331, 332 } }, -- Chest of the Corrupted Protector
    [78865] = { slot = 10, classMask = 1192, instances = { 187 }, encounters = { 311, 317, 324, 325, 331, 332 } }, -- Gauntlets of the Corrupted Vanquisher
    [78866] = { slot = 10, classMask = 274, instances = { 187 }, encounters = { 311, 317, 324, 325, 331, 332 } }, -- Gauntlets of the Corrupted Conqueror
    [78867] = { slot = 10, classMask = 69, instances = { 187 }, encounters = { 311, 317, 324, 325, 331, 332 } }, -- Gauntlets of the Corrupted Protector
    [78868] = { slot = 1, classMask = 1192, instances = { 187 }, encounters = { 311, 317, 324, 325, 331, 332 } }, -- Crown of the Corrupted Vanquisher
    [78869] = { slot = 1, classMask = 274, instances = { 187 }, encounters = { 311, 317, 324, 325, 331, 332 } }, -- Crown of the Corrupted Conqueror
    [78870] = { slot = 1, classMask = 69, instances = { 187 }, encounters = { 311, 317, 324, 325, 331, 332 } }, -- Crown of the Corrupted Protector
    [78871] = { slot = 7, classMask = 1192, instances = { 187 }, encounters = { 311, 317, 324, 325, 331, 332 } }, -- Leggings of the Corrupted Vanquisher
    [78872] = { slot = 7, classMask = 274, instances = { 187 }, encounters = { 311, 317, 324, 325, 331, 332 } }, -- Leggings of the Corrupted Conqueror
    [78873] = { slot = 7, classMask = 69, instances = { 187 }, encounters = { 311, 317, 324, 325, 331, 332 } }, -- Leggings of the Corrupted Protector
    [78874] = { slot = 3, classMask = 1192, instances = { 187 }, encounters = { 311, 317, 324, 325, 331, 332 } }, -- Shoulders of the Corrupted Vanquisher
    [78875] = { slot = 3, classMask = 274, instances = { 187 }, encounters = { 311, 317, 324, 325, 331, 332 } }, -- Shoulders of the Corrupted Conqueror
    [78876] = { slot = 3, classMask = 69, instances = { 187 }, encounters = { 311, 317, 324, 325, 331, 332 } }, -- Shoulders of the Corrupted Protector
    [89234] = { slot = 1, classMask = 1192, instances = { 320 }, encounters = { 709 } }, -- Helm of the Shadowy Vanquisher
    [89235] = { slot = 1, classMask = 274, instances = { 320 }, encounters = { 709 } }, -- Helm of the Shadowy Conqueror
    [89236] = { slot = 1, classMask = 581, instances = { 320 }, encounters = { 709 } }, -- Helm of the Shadowy Protector
    [89237] = { slot = 5, classMask = 274, instances = { 330 }, encounters = { 743 } }, -- Chest of the Shadowy Conqueror
    [89238] = { slot = 5, classMask = 581, instances = { 330 }, encounters = { 743 } }, -- Chest of the Shadowy Protector
    [89239] = { slot = 5, classMask = 1192, instances = { 330 }, encounters = { 743 } }, -- Chest of the Shadowy Vanquisher
    [89240] = { slot = 10, classMask = 274, instances = { 330 }, encounters = { 741 } }, -- Gauntlets of the Shadowy Conqueror
    [89241] = { slot = 10, classMask = 581, instances = { 330 }, encounters = { 741 } }, -- Gauntlets of the Shadowy Protector
    [89242] = { slot = 10, classMask = 1192, instances = { 330 }, encounters = { 741 } }, -- Gauntlets of the Shadowy Vanquisher
    [89243] = { slot = 7, classMask = 274, instances = { 330 }, encounters = { 737 } }, -- Leggings of the Shadowy Conqueror
    [89244] = { slot = 7, classMask = 581, instances = { 330 }, encounters = { 737 } }, -- Leggings of the Shadowy Protector
    [89245] = { slot = 7, classMask = 1192, instances = { 330 }, encounters = { 737 } }, -- Leggings of the Shadowy Vanquisher
    [89246] = { slot = 3, classMask = 274, instances = { 320 }, encounters = { 729 } }, -- Shoulders of the Shadowy Conqueror
    [89247] = { slot = 3, classMask = 581, instances = { 320 }, encounters = { 729 } }, -- Shoulders of the Shadowy Protector
    [89248] = { slot = 3, classMask = 1192, instances = { 320 }, encounters = { 729 } }, -- Shoulders of the Shadowy Vanquisher
    [89249] = { slot = 5, classMask = 1192, instances = { 330 }, encounters = { 743 } }, -- Chest of the Shadowy Vanquisher
    [89250] = { slot = 5, classMask = 274, instances = { 330 }, encounters = { 743 } }, -- Chest of the Shadowy Conqueror
    [89251] = { slot = 5, classMask = 581, instances = { 330 }, encounters = { 743 } }, -- Chest of the Shadowy Protector
    [89252] = { slot = 7, classMask = 1192, instances = { 330 }, encounters = { 737 } }, -- Leggings of the Shadowy Vanquisher
    [89253] = { slot = 7, classMask = 274, instances = { 330 }, encounters = { 737 } }, -- Leggings of the Shadowy Conqueror
    [89254] = { slot = 7, classMask = 581, instances = { 330 }, encounters = { 737 } }, -- Leggings of the Shadowy Protector
    [89255] = { slot = 10, classMask = 1192, instances = { 330 }, encounters = { 741 } }, -- Gauntlets of the Shadowy Vanquisher
    [89256] = { slot = 10, classMask = 274, instances = { 330 }, encounters = { 741 } }, -- Gauntlets of the Shadowy Conqueror
    [89257] = { slot = 10, classMask = 581, instances = { 330 }, encounters = { 741 } }, -- Gauntlets of the Shadowy Protector
    [89258] = { slot = 1, classMask = 1192, instances = { 320 }, encounters = { 709 } }, -- Helm of the Shadowy Vanquisher
    [89259] = { slot = 1, classMask = 274, instances = { 320 }, encounters = { 709 } }, -- Helm of the Shadowy Conqueror
    [89260] = { slot = 1, classMask = 581, instances = { 320 }, encounters = { 709 } }, -- Helm of the Shadowy Protector
    [89261] = { slot = 3, classMask = 1192, instances = { 320 }, encounters = { 729 } }, -- Shoulders of the Shadowy Vanquisher
    [89262] = { slot = 3, classMask = 274, instances = { 320 }, encounters = { 729 } }, -- Shoulders of the Shadowy Conqueror
    [89263] = { slot = 3, classMask = 581, instances = { 320 }, encounters = { 729 } }, -- Shoulders of the Shadowy Protector
    [89264] = { slot = 5, classMask = 1192, instances = { 330 }, encounters = { 743 } }, -- Chest of the Shadowy Vanquisher
    [89265] = { slot = 5, classMask = 274, instances = { 330 }, encounters = { 743 } }, -- Chest of the Shadowy Conqueror
    [89266] = { slot = 5, classMask = 581, instances = { 330 }, encounters = { 743 } }, -- Chest of the Shadowy Protector
    [89267] = { slot = 7, classMask = 1192, instances = { 330 }, encounters = { 737 } }, -- Leggings of the Shadowy Vanquisher
    [89268] = { slot = 7, classMask = 274, instances = { 330 }, encounters = { 737 } }, -- Leggings of the Shadowy Conqueror
    [89269] = { slot = 7, classMask = 581, instances = { 330 }, encounters = { 737 } }, -- Leggings of the Shadowy Protector
    [89270] = { slot = 10, classMask = 1192, instances = { 330 }, encounters = { 741 } }, -- Gauntlets of the Shadowy Vanquisher
    [89271] = { slot = 10, classMask = 274, instances = { 330 }, encounters = { 741 } }, -- Gauntlets of the Shadowy Conqueror
    [89272] = { slot = 10, classMask = 581, instances = { 330 }, encounters = { 741 } }, -- Gauntlets of the Shadowy Protector
    [89273] = { slot = 1, classMask = 1192, instances = { 320 }, encounters = { 709 } }, -- Helm of the Shadowy Vanquisher
    [89274] = { slot = 1, classMask = 274, instances = { 320 }, encounters = { 709 } }, -- Helm of the Shadowy Conqueror
    [89275] = { slot = 1, classMask = 581, instances = { 320 }, encounters = { 709 } }, -- Helm of the Shadowy Protector
    [89276] = { slot = 3, classMask = 1192, instances = { 320 }, encounters = { 729 } }, -- Shoulders of the Shadowy Vanquisher
    [89277] = { slot = 3, classMask = 274, instances = { 320 }, encounters = { 729 } }, -- Shoulders of the Shadowy Conqueror
    [89278] = { slot = 3, classMask = 581, instances = { 320 }, encounters = { 729 } }, -- Shoulders of the Shadowy Protector
    [95569] = { slot = 5, classMask = 1192, instances = { 362 }, encounters = { 824 } }, -- Chest of the Crackling Vanquisher
    [95570] = { slot = 10, classMask = 1192, instances = { 362 }, encounters = { 816 } }, -- Gauntlets of the Crackling Vanquisher
    [95571] = { slot = 1, classMask = 1192, instances = { 362 }, encounters = { 829 } }, -- Helm of the Crackling Vanquisher
    [95572] = { slot = 7, classMask = 1192, instances = { 362 }, encounters = { 828 } }, -- Leggings of the Crackling Vanquisher
    [95573] = { slot = 3, classMask = 1192, instances = { 362 }, encounters = { 817 } }, -- Shoulders of the Crackling Vanquisher
    [95574] = { slot = 5, classMask = 274, instances = { 362 }, encounters = { 824 } }, -- Chest of the Crackling Conqueror
    [95575] = { slot = 10, classMask = 274, instances = { 362 }, encounters = { 816 } }, -- Gauntlets of the Crackling Conqueror
    [95576] = { slot = 7, classMask = 274, instances = { 362 }, encounters = { 828 } }, -- Leggings of the Crackling Conqueror
    [95577] = { slot = 1, classMask = 274, instances = { 362 }, encounters = { 829 } }, -- Helm of the Crackling Conqueror
    [95578] = { slot = 3, classMask = 274, instances = { 362 }, encounters = { 817 } }, -- Shoulders of the Crackling Conqueror
    [95579] = { slot = 5, classMask = 581, instances = { 362 }, encounters = { 824 } }, -- Chest of the Crackling Protector
    [95580] = { slot = 10, classMask = 581, instances = { 362 }, encounters = { 816 } }, -- Gauntlets of the Crackling Protector
    [95581] = { slot = 7, classMask = 581, instances = { 362 }, encounters = { 828 } }, -- Leggings of the Crackling Protector
    [95582] = { slot = 1, classMask = 581, instances = { 362 }, encounters = { 829 } }, -- Helm of the Crackling Protector
    [95583] = { slot = 3, classMask = 581, instances = { 362 }, encounters = { 817 } }, -- Shoulders of the Crackling Protector
    [95822] = { slot = 5, classMask = 1192, instances = { 362 }, encounters = { 824 } }, -- Chest of the Crackling Vanquisher
    [95823] = { slot = 5, classMask = 274, instances = { 362 }, encounters = { 824 } }, -- Chest of the Crackling Conqueror
    [95824] = { slot = 5, classMask = 581, instances = { 362 }, encounters = { 824 } }, -- Chest of the Crackling Protector
    [95855] = { slot = 10, classMask = 1192, instances = { 362 }, encounters = { 816 } }, -- Gauntlets of the Crackling Vanquisher
    [95856] = { slot = 10, classMask = 274, instances = { 362 }, encounters = { 816 } }, -- Gauntlets of the Crackling Conqueror
    [95857] = { slot = 10, classMask = 581, instances = { 362 }, encounters = { 816 } }, -- Gauntlets of the Crackling Protector
    [95879] = { slot = 1, classMask = 1192, instances = { 362 }, encounters = { 829 } }, -- Helm of the Crackling Vanquisher
    [95880] = { slot = 1, classMask = 274, instances = { 362 }, encounters = { 829 } }, -- Helm of the Crackling Conqueror
    [95881] = { slot = 1, classMask = 581, instances = { 362 }, encounters = { 829 } }, -- Helm of the Crackling Protector
    [95887] = { slot = 7, classMask = 1192, instances = { 362 }, encounters = { 828 } }, -- Leggings of the Crackling Vanquisher
    [95888] = { slot = 7, classMask = 274, instances = { 362 }, encounters = { 828 } }, -- Leggings of the Crackling Conqueror
    [95889] = { slot = 7, classMask = 581, instances = { 362 }, encounters = { 828 } }, -- Leggings of the Crackling Protector
    [95955] = { slot = 3, classMask = 1192, instances = { 362 }, encounters = { 817 } }, -- Shoulders of the Crackling Vanquisher
    [95956] = { slot = 3, classMask = 274, instances = { 362 }, encounters = { 817 } }, -- Shoulders of the Crackling Conqueror
    [95957] = { slot = 3, classMask = 581, instances = { 362 }, encounters = { 817 } }, -- Shoulders of the Crackling Protector
    [96566] = { slot = 5, classMask = 1192, instances = { 362 }, encounters = { 824 } }, -- Chest of the Crackling Vanquisher
    [96567] = { slot = 5, classMask = 274, instances = { 362 }, encounters = { 824 } }, -- Chest of the Crackling Conqueror
    [96568] = { slot = 5, classMask = 581, instances = { 362 }, encounters = { 824 } }, -- Chest of the Crackling Protector
    [96599] = { slot = 10, classMask = 1192, instances = { 362 }, encounters = { 816 } }, -- Gauntlets of the Crackling Vanquisher
    [96600] = { slot = 10, classMask = 274, instances = { 362 }, encounters = { 816 } }, -- Gauntlets of the Crackling Conqueror
    [96601] = { slot = 10, classMask = 581, instances = { 362 }, encounters = { 816 } }, -- Gauntlets of the Crackling Protector
    [96623] = { slot = 1, classMask = 1192, instances = { 362 }, encounters = { 829 } }, -- Helm of the Crackling Vanquisher
    [96624] = { slot = 1, classMask = 274, instances = { 362 }, encounters = { 829 } }, -- Helm of the Crackling Conqueror
    [96625] = { slot = 1, classMask = 581, instances = { 362 }, encounters = { 829 } }, -- Helm of the Crackling Protector
    [96631] = { slot = 7, classMask = 1192, instances = { 362 }, encounters = { 828 } }, -- Leggings of the Crackling Vanquisher
    [96632] = { slot = 7, classMask = 274, instances = { 362 }, encounters = { 828 } }, -- Leggings of the Crackling Conqueror
    [96633] = { slot = 7, classMask = 581, instances = { 362 }, encounters = { 828 } }, -- Leggings of the Crackling Protector
    [96699] = { slot = 3, classMask = 1192, instances = { 362 }, encounters = { 817 } }, -- Shoulders of the Crackling Vanquisher
    [96700] = { slot = 3, classMask = 274, instances = { 362 }, encounters = { 817 } }, -- Shoulders of the Crackling Conqueror
    [96701] = { slot = 3, classMask = 581, instances = { 362 }, encounters = { 817 } }, -- Shoulders of the Crackling Protector
    [99667] = { slot = 10, classMask = 581, instances = { 369 }, encounters = { 850 } }, -- Gauntlets of the Cursed Protector
    [99668] = { slot = 3, classMask = 1192, instances = { 369 }, encounters = { 865 } }, -- Shoulders of the Cursed Vanquisher
    [99669] = { slot = 3, classMask = 274, instances = { 369 }, encounters = { 865 } }, -- Shoulders of the Cursed Conqueror
    [99670] = { slot = 3, classMask = 581, instances = { 369 }, encounters = { 865 } }, -- Shoulders of the Cursed Protector
    [99671] = { slot = 1, classMask = 1192, instances = { 369 }, encounters = { 851 } }, -- Helm of the Cursed Vanquisher
    [99672] = { slot = 1, classMask = 274, instances = { 369 }, encounters = { 851 } }, -- Helm of the Cursed Conqueror
    [99673] = { slot = 1, classMask = 581, instances = { 369 }, encounters = { 851 } }, -- Helm of the Cursed Protector
    [99674] = { slot = 7, classMask = 1192, instances = { 369 }, encounters = { 853 } }, -- Leggings of the Cursed Vanquisher
    [99675] = { slot = 7, classMask = 274, instances = { 369 }, encounters = { 853 } }, -- Leggings of the Cursed Conqueror
    [99676] = { slot = 7, classMask = 581, instances = { 369 }, encounters = { 853 } }, -- Leggings of the Cursed Protector
    [99677] = { slot = 5, classMask = 1192, instances = { 369 }, encounters = { 867 } }, -- Chest of the Cursed Vanquisher
    [99678] = { slot = 5, classMask = 274, instances = { 369 }, encounters = { 867 } }, -- Chest of the Cursed Conqueror
    [99679] = { slot = 5, classMask = 581, instances = { 369 }, encounters = { 867 } }, -- Chest of the Cursed Protector
    [99680] = { slot = 10, classMask = 1192, instances = { 369 }, encounters = { 850 } }, -- Gauntlets of the Cursed Vanquisher
    [99681] = { slot = 10, classMask = 274, instances = { 369 }, encounters = { 850 } }, -- Gauntlets of the Cursed Conqueror
    [99682] = { slot = 10, classMask = 1192, instances = { 369 }, encounters = { 850 } }, -- Gauntlets of the Cursed Vanquisher
    [99683] = { slot = 1, classMask = 1192, instances = { 369 }, encounters = { 851 } }, -- Helm of the Cursed Vanquisher
    [99684] = { slot = 7, classMask = 1192, instances = { 369 }, encounters = { 853 } }, -- Leggings of the Cursed Vanquisher
    [99685] = { slot = 3, classMask = 1192, instances = { 369 }, encounters = { 865 } }, -- Shoulders of the Cursed Vanquisher
    [99686] = { slot = 5, classMask = 274, instances = { 369 }, encounters = { 867 } }, -- Chest of the Cursed Conqueror
    [99687] = { slot = 10, classMask = 274, instances = { 369 }, encounters = { 850 } }, -- Gauntlets of the Cursed Conqueror
    [99688] = { slot = 7, classMask = 274, instances = { 369 }, encounters = { 853 } }, -- Leggings of the Cursed Conqueror
    [99689] = { slot = 1, classMask = 274, instances = { 369 }, encounters = { 851 } }, -- Helm of the Cursed Conqueror
    [99690] = { slot = 3, classMask = 274, instances = { 369 }, encounters = { 865 } }, -- Shoulders of the Cursed Conqueror
    [99691] = { slot = 5, classMask = 581, instances = { 369 }, encounters = { 867 } }, -- Chest of the Cursed Protector
    [99692] = { slot = 10, classMask = 581, instances = { 369 }, encounters = { 850 } }, -- Gauntlets of the Cursed Protector
    [99693] = { slot = 7, classMask = 581, instances = { 369 }, encounters = { 853 } }, -- Leggings of the Cursed Protector
    [99694] = { slot = 1, classMask = 581, instances = { 369 }, encounters = { 851 } }, -- Helm of the Cursed Protector
    [99695] = { slot = 3, classMask = 581, instances = { 369 }, encounters = { 865 } }, -- Shoulders of the Cursed Protector
    [99696] = { slot = 5, classMask = 1192, instances = { 369 }, encounters = { 867 } }, -- Chest of the Cursed Vanquisher
    [99713] = { slot = 7, classMask = 581, instances = { 369 }, encounters = { 853 } }, -- Leggings of the Cursed Protector
    [99714] = { slot = 5, classMask = 1192, instances = { 369 }, encounters = { 867 } }, -- Chest of the Cursed Vanquisher
    [99715] = { slot = 5, classMask = 274, instances = { 369 }, encounters = { 867 } }, -- Chest of the Cursed Conqueror
    [99716] = { slot = 5, classMask = 581, instances = { 369 }, encounters = { 867 } }, -- Chest of the Cursed Protector
    [99717] = { slot = 3, classMask = 1192, instances = { 369 }, encounters = { 865 } }, -- Shoulders of the Cursed Vanquisher
    [99718] = { slot = 3, classMask = 274, instances = { 369 }, encounters = { 865 } }, -- Shoulders of the Cursed Conqueror
    [99719] = { slot = 3, classMask = 581, instances = { 369 }, encounters = { 865 } }, -- Shoulders of the Cursed Protector
    [99720] = { slot = 10, classMask = 1192, instances = { 369 }, encounters = { 850 } }, -- Gauntlets of the Cursed Vanquisher
    [99721] = { slot = 10, classMask = 274, instances = { 369 }, encounters = { 850 } }, -- Gauntlets of the Cursed Conqueror
    [99722] = { slot = 10, classMask = 581, instances = { 369 }, encounters = { 850 } }, -- Gauntlets of the Cursed Protector
    [99723] = { slot = 1, classMask = 1192, instances = { 369 }, encounters = { 851 } }, -- Helm of the Cursed Vanquisher
    [99724] = { slot = 1, classMask = 274, instances = { 369 }, encounters = { 851 } }, -- Helm of the Cursed Conqueror
    [99725] = { slot = 1, classMask = 581, instances = { 369 }, encounters = { 851 } }, -- Helm of the Cursed Protector
    [99726] = { slot = 7, classMask = 1192, instances = { 369 }, encounters = { 853 } }, -- Leggings of the Cursed Vanquisher
    [105857] = { slot = 0, classMask = 581, instances = { 369 }, encounters = { 869 } }, -- Essence of the Cursed Protector
    [105858] = { slot = 0, classMask = 274, instances = { 369 }, encounters = { 869 } }, -- Essence of the Cursed Conqueror
    [105859] = { slot = 0, classMask = 1192, instances = { 369 }, encounters = { 869 } }, -- Essence of the Cursed Vanquisher
    [105860] = { slot = 0, classMask = 581, instances = { 369 }, encounters = { 869 } }, -- Essence of the Cursed Protector
    [105861] = { slot = 0, classMask = 274, instances = { 369 }, encounters = { 869 } }, -- Essence of the Cursed Conqueror
    [105862] = { slot = 0, classMask = 1192, instances = { 369 }, encounters = { 869 } }, -- Essence of the Cursed Vanquisher
    [105866] = { slot = 0, classMask = 581, instances = { 369 }, encounters = { 869 } }, -- Essence of the Cursed Protector
    [105867] = { slot = 0, classMask = 274, instances = { 369 }, encounters = { 869 } }, -- Essence of the Cursed Conqueror
    [105868] = { slot = 0, classMask = 1192, instances = { 369 }, encounters = { 869 } }, -- Essence of the Cursed Vanquisher
    [119305] = { slot = 5, classMask = 274, instances = { 457 }, encounters = { 1123 } }, -- Chest of the Iron Conqueror
    [119306] = { slot = 10, classMask = 274, instances = { 457 }, encounters = { 1203 } }, -- Gauntlets of the Iron Conqueror
    [119307] = { slot = 7, classMask = 274, instances = { 457 }, encounters = { 1154 } }, -- Leggings of the Iron Conqueror
    [119308] = { slot = 1, classMask = 274, instances = { 457 }, encounters = { 1162 } }, -- Helm of the Iron Conqueror
    [119309] = { slot = 3, classMask = 274, instances = { 457 }, encounters = { 1147 } }, -- Shoulders of the Iron Conqueror
    [119310] = { slot = 0, classMask = 274, instances = { 457 }, encounters = { 959 } }, -- Essence of the Iron Conqueror
    [119311] = { slot = 10, classMask = 1192, instances = { 457 }, encounters = { 1203 } }, -- Gauntlets of the Iron Vanquisher
    [119312] = { slot = 1, classMask = 1192, instances = { 457 }, encounters = { 1162 } }, -- Helm of the Iron Vanquisher
    [119313] = { slot = 7, classMask = 1192, instances = { 457 }, encounters = { 1154 } }, -- Leggings of the Iron Vanquisher
    [119314] = { slot = 3, classMask = 1192, instances = { 457 }, encounters = { 1147 } }, -- Shoulders of the Iron Vanquisher
    [119315] = { slot = 5, classMask = 1192, instances = { 457 }, encounters = { 1123 } }, -- Chest of the Iron Vanquisher
    [119316] = { slot = 0, classMask = 1192, instances = { 457 }, encounters = { 959 } }, -- Essence of the Iron Vanquisher
    [119318] = { slot = 5, classMask = 581, instances = { 457 }, encounters = { 1123 } }, -- Chest of the Iron Protector
    [119319] = { slot = 10, classMask = 581, instances = { 457 }, encounters = { 1203 } }, -- Gauntlets of the Iron Protector
    [119320] = { slot = 7, classMask = 581, instances = { 457 }, encounters = { 1154 } }, -- Leggings of the Iron Protector
    [119321] = { slot = 1, classMask = 581, instances = { 457 }, encounters = { 1162 } }, -- Helm of the Iron Protector
    [119322] = { slot = 3, classMask = 581, instances = { 457 }, encounters = { 1147 } }, -- Shoulders of the Iron Protector
    [119323] = { slot = 0, classMask = 581, instances = { 457 }, encounters = { 959 } }, -- Essence of the Iron Protector
    [120277] = { slot = 0, classMask = 274, instances = { 457 }, encounters = { 959 } }, -- Essence of the Iron Conqueror
    [120278] = { slot = 0, classMask = 1192, instances = { 457 }, encounters = { 959 } }, -- Essence of the Iron Vanquisher
    [120279] = { slot = 0, classMask = 581, instances = { 457 }, encounters = { 959 } }, -- Essence of the Iron Protector
    [191002] = { slot = 1, classMask = 1156, instances = { 1195 }, encounters = { 2469 } }, -- Mystic Helm Module
    [191003] = { slot = 1, classMask = 82, instances = { 1195 }, encounters = { 2469 } }, -- Venerated Helm Module
    [191004] = { slot = 1, classMask = 521, instances = { 1195 }, encounters = { 2469 } }, -- Zenith Helm Module
    [191005] = { slot = 1, classMask = 2336, instances = { 1195 }, encounters = { 2469 } }, -- Dreadful Helm Module
    [191006] = { slot = 3, classMask = 2336, instances = { 1195 }, encounters = { 2457 } }, -- Dreadful Shoulder Module
    [191007] = { slot = 3, classMask = 1156, instances = { 1195 }, encounters = { 2457 } }, -- Mystic Shoulder Module
    [191008] = { slot = 3, classMask = 82, instances = { 1195 }, encounters = { 2457 } }, -- Venerated Shoulder Module
    [191009] = { slot = 3, classMask = 521, instances = { 1195 }, encounters = { 2457 } }, -- Zenith Shoulder Module
    [191010] = { slot = 5, classMask = 2336, instances = { 1195 }, encounters = { 2467 } }, -- Dreadful Chest Module
    [191011] = { slot = 5, classMask = 1156, instances = { 1195 }, encounters = { 2467 } }, -- Mystic Chest Module
    [191012] = { slot = 5, classMask = 82, instances = { 1195 }, encounters = { 2467 } }, -- Venerated Chest Module
    [191013] = { slot = 5, classMask = 521, instances = { 1195 }, encounters = { 2467 } }, -- Zenith Chest Module
    [191014] = { slot = 10, classMask = 2336, instances = { 1195 }, encounters = { 2461 } }, -- Dreadful Hand Module
    [191015] = { slot = 10, classMask = 1156, instances = { 1195 }, encounters = { 2461 } }, -- Mystic Hand Module
    [191016] = { slot = 10, classMask = 82, instances = { 1195 }, encounters = { 2461 } }, -- Venerated Hand Module
    [191017] = { slot = 10, classMask = 521, instances = { 1195 }, encounters = { 2461 } }, -- Zenith Hand Module
    [191018] = { slot = 7, classMask = 2336, instances = { 1195 }, encounters = { 2463 } }, -- Dreadful Leg Module
    [191019] = { slot = 7, classMask = 1156, instances = { 1195 }, encounters = { 2463 } }, -- Mystic Leg Module
    [191020] = { slot = 7, classMask = 82, instances = { 1195 }, encounters = { 2463 } }, -- Venerated Leg Module
    [191021] = { slot = 7, classMask = 521, instances = { 1195 }, encounters = { 2463 } }, -- Zenith Leg Module
    [196586] = { slot = 5, classMask = 2336, instances = { 1200 }, encounters = { 2491 } }, -- Dreadful Amethyst Forgestone
    [196587] = { slot = 10, classMask = 2336, instances = { 1200 }, encounters = { 2502 } }, -- Dreadful Garnet Forgestone
    [196588] = { slot = 7, classMask = 2336, instances = { 1200 }, encounters = { 2482 } }, -- Dreadful Jade Forgestone
    [196589] = { slot = 3, classMask = 2336, instances = { 1200 }, encounters = { 2493 } }, -- Dreadful Lapis Forgestone
    [196590] = { slot = 1, classMask = 2336, instances = { 1200 }, encounters = { 2499 } }, -- Dreadful Topaz Forgestone
    [196591] = { slot = 5, classMask = 4617, instances = { 1200 }, encounters = { 2491 } }, -- Zenith Amethyst Forgestone
    [196592] = { slot = 10, classMask = 4617, instances = { 1200 }, encounters = { 2502 } }, -- Zenith Garnet Forgestone
    [196593] = { slot = 7, classMask = 4617, instances = { 1200 }, encounters = { 2482 } }, -- Zenith Jade Forgestone
    [196594] = { slot = 3, classMask = 4617, instances = { 1200 }, encounters = { 2493 } }, -- Zenith Lapis Forgestone
    [196595] = { slot = 1, classMask = 4617, instances = { 1200 }, encounters = { 2499 } }, -- Zenith Topaz Forgestone
    [196596] = { slot = 5, classMask = 1156, instances = { 1200 }, encounters = { 2491 } }, -- Mystic Amethyst Forgestone
    [196597] = { slot = 10, classMask = 1156, instances = { 1200 }, encounters = { 2502 } }, -- Mystic Garnet Forgestone
    [196598] = { slot = 7, classMask = 1156, instances = { 1200 }, encounters = { 2482 } }, -- Mystic Jade Forgestone
    [196599] = { slot = 3, classMask = 1156, instances = { 1200 }, encounters = { 2493 } }, -- Mystic Lapis Forgestone
    [196600] = { slot = 1, classMask = 1156, instances = { 1200 }, encounters = { 2499 } }, -- Mystic Topaz Forgestone
    [196601] = { slot = 5, classMask = 82, instances = { 1200 }, encounters = { 2491 } }, -- Venerated Amethyst Forgestone
    [196602] = { slot = 10, classMask = 82, instances = { 1200 }, encounters = { 2502 } }, -- Venerated Garnet Forgestone
    [196603] = { slot = 7, classMask = 82, instances = { 1200 }, encounters = { 2482 } }, -- Venerated Jade Forgestone
    [196604] = { slot = 3, classMask = 82, instances = { 1200 }, encounters = { 2493 } }, -- Venerated Lapis Forgestone
    [196605] = { slot = 1, classMask = 82, instances = { 1200 }, encounters = { 2499 } }, -- Venerated Topaz Forgestone
    [202621] = { slot = 3, classMask = 2336, instances = { 1208 }, encounters = { 2523 } }, -- Dreadful Corrupting Fluid
    [202622] = { slot = 3, classMask = 1156, instances = { 1208 }, encounters = { 2523 } }, -- Mystic Corrupting Fluid
    [202623] = { slot = 3, classMask = 82, instances = { 1208 }, encounters = { 2523 } }, -- Venerated Corrupting Fluid
    [202624] = { slot = 10, classMask = 2336, instances = { 1208 }, encounters = { 2530 } }, -- Dreadful Mixing Fluid
    [202625] = { slot = 10, classMask = 1156, instances = { 1208 }, encounters = { 2530 } }, -- Mystic Mixing Fluid
    [202626] = { slot = 10, classMask = 82, instances = { 1208 }, encounters = { 2530 } }, -- Venerated Mixing Fluid
    [202627] = { slot = 1, classMask = 2336, instances = { 1208 }, encounters = { 2527 } }, -- Dreadful Melting Fluid
    [202628] = { slot = 1, classMask = 1156, instances = { 1208 }, encounters = { 2527 } }, -- Mystic Melting Fluid
    [202629] = { slot = 1, classMask = 82, instances = { 1208 }, encounters = { 2527 } }, -- Venerated Melting Fluid
    [202630] = { slot = 1, classMask = 4617, instances = { 1208 }, encounters = { 2527 } }, -- Zenith Melting Fluid
    [202631] = { slot = 5, classMask = 2336, instances = { 1208 }, encounters = { 2532 } }, -- Dreadful Ventilation Fluid
    [202632] = { slot = 5, classMask = 1156, instances = { 1208 }, encounters = { 2532 } }, -- Mystic Ventilation Fluid
    [202633] = { slot = 5, classMask = 82, instances = { 1208 }, encounters = { 2532 } }, -- Venerated Ventilation Fluid
    [202634] = { slot = 7, classMask = 2336, instances = { 1208 }, encounters = { 2525 } }, -- Dreadful Cooling Fluid
    [202635] = { slot = 7, classMask = 1156, instances = { 1208 }, encounters = { 2525 } }, -- Mystic Cooling Fluid
    [202636] = { slot = 7, classMask = 82, instances = { 1208 }, encounters = { 2525 } }, -- Venerated Cooling Fluid
    [202637] = { slot = 3, classMask = 4617, instances = { 1208 }, encounters = { 2523 } }, -- Zenith Corrupting Fluid
    [202638] = { slot = 10, classMask = 4617, instances = { 1208 }, encounters = { 2530 } }, -- Zenith Mixing Fluid
    [202639] = { slot = 5, classMask = 4617, instances = { 1208 }, encounters = { 2532 } }, -- Zenith Ventilation Fluid
    [202640] = { slot = 7, classMask = 4617, instances = { 1208 }, encounters = { 2525 } }, -- Zenith Cooling Fluid
    [207462] = { slot = 5, classMask = 2336, instances = { 1207 }, encounters = { 2556 } }, -- Dreadful Verdurous Dreamheart
    [207463] = { slot = 5, classMask = 1156, instances = { 1207 }, encounters = { 2556 } }, -- Mystic Verdurous Dreamheart
    [207464] = { slot = 5, classMask = 82, instances = { 1207 }, encounters = { 2556 } }, -- Venerated Verdurous Dreamheart
    [207465] = { slot = 5, classMask = 4617, instances = { 1207 }, encounters = { 2556 } }, -- Zenith Verdurous Dreamheart
    [207466] = { slot = 10, classMask = 2336, instances = { 1207 }, encounters = { 2554 } }, -- Dreadful Tormented Dreamheart
    [207467] = { slot = 10, classMask = 1156, instances = { 1207 }, encounters = { 2554 } }, -- Mystic Tormented Dreamheart
    [207468] = { slot = 10, classMask = 82, instances = { 1207 }, encounters = { 2554 } }, -- Venerated Tormented Dreamheart
    [207469] = { slot = 10, classMask = 4617, instances = { 1207 }, encounters = { 2554 } }, -- Zenith Tormented Dreamheart
    [207470] = { slot = 1, classMask = 2336, instances = { 1207 }, encounters = { 2565 } }, -- Dreadful Blazing Dreamheart
    [207471] = { slot = 1, classMask = 1156, instances = { 1207 }, encounters = { 2565 } }, -- Mystic Blazing Dreamheart
    [207472] = { slot = 1, classMask = 82, instances = { 1207 }, encounters = { 2565 } }, -- Venerated Blazing Dreamheart
    [207473] = { slot = 1, classMask = 4617, instances = { 1207 }, encounters = { 2565 } }, -- Zenith Blazing Dreamheart
    [207474] = { slot = 7, classMask = 2336, instances = { 1207 }, encounters = { 2553 } }, -- Dreadful Ashen Dreamheart
    [207475] = { slot = 7, classMask = 1156, instances = { 1207 }, encounters = { 2553 } }, -- Mystic Ashen Dreamheart
    [207476] = { slot = 7, classMask = 82, instances = { 1207 }, encounters = { 2553 } }, -- Venerated Ashen Dreamheart
    [207477] = { slot = 7, classMask = 4617, instances = { 1207 }, encounters = { 2553 } }, -- Zenith Ashen Dreamheart
    [207478] = { slot = 3, classMask = 2336, instances = { 1207 }, encounters = { 2563 } }, -- Dreadful Smoldering Dreamheart
    [207479] = { slot = 3, classMask = 1156, instances = { 1207 }, encounters = { 2563 } }, -- Mystic Smoldering Dreamheart
    [207480] = { slot = 3, classMask = 82, instances = { 1207 }, encounters = { 2563 } }, -- Venerated Smoldering Dreamheart
    [207481] = { slot = 3, classMask = 4617, instances = { 1207 }, encounters = { 2563 } }, -- Zenith Smoldering Dreamheart
    [217316] = { slot = 5, classMask = 2336, instances = { 1200, 1207, 1208 }, encounters = { 2491, 2532, 2556 } }, -- Dreadful Fleeting Hourglass
    [217317] = { slot = 5, classMask = 1156, instances = { 1200, 1207, 1208 }, encounters = { 2491, 2532, 2556 } }, -- Mystic Fleeting Hourglass
    [217318] = { slot = 5, classMask = 82, instances = { 1200, 1207, 1208 }, encounters = { 2491, 2532, 2556 } }, -- Venerated Fleeting Hourglass
    [217319] = { slot = 5, classMask = 4617, instances = { 1200, 1207, 1208 }, encounters = { 2491, 2532, 2556 } }, -- Zenith Fleeting Hourglass
    [217320] = { slot = 10, classMask = 2336, instances = { 1200, 1207, 1208 }, encounters = { 2502, 2530, 2554 } }, -- Dreadful Quickened Bronzestone
    [217321] = { slot = 10, classMask = 1156, instances = { 1200, 1207, 1208 }, encounters = { 2502, 2530, 2554 } }, -- Mystic Quickened Bronzestone
    [217322] = { slot = 10, classMask = 82, instances = { 1200, 1207, 1208 }, encounters = { 2502, 2530, 2554 } }, -- Venerated Quickened Bronzestone
    [217323] = { slot = 10, classMask = 4617, instances = { 1200, 1207, 1208 }, encounters = { 2502, 2530, 2554 } }, -- Zenith Quickened Bronzestone
    [217324] = { slot = 1, classMask = 2336, instances = { 1200, 1207, 1208 }, encounters = { 2499, 2527, 2565 } }, -- Dreadful Decelerating Chronograph
    [217325] = { slot = 1, classMask = 1156, instances = { 1200, 1207, 1208 }, encounters = { 2499, 2527, 2565 } }, -- Mystic Decelerating Chronograph
    [217326] = { slot = 1, classMask = 82, instances = { 1200, 1207, 1208 }, encounters = { 2499, 2527, 2565 } }, -- Venerated Decelerating Chronograph
    [217327] = { slot = 1, classMask = 4617, instances = { 1200, 1207, 1208 }, encounters = { 2499, 2527, 2565 } }, -- Zenith Decelerating Chronograph
    [217328] = { slot = 7, classMask = 2336, instances = { 1200, 1207, 1208 }, encounters = { 2482, 2525, 2553 } }, -- Dreadful Ephemeral Hypersphere
    [217329] = { slot = 7, classMask = 1156, instances = { 1200, 1207, 1208 }, encounters = { 2482, 2525, 2553 } }, -- Mystic Ephemeral Hypersphere
    [217330] = { slot = 7, classMask = 82, instances = { 1200, 1207, 1208 }, encounters = { 2482, 2525, 2553 } }, -- Venerated Ephemeral Hypersphere
    [217331] = { slot = 7, classMask = 4617, instances = { 1200, 1207, 1208 }, encounters = { 2482, 2525, 2553 } }, -- Zenith Ephemeral Hypersphere
    [217332] = { slot = 3, classMask = 2336, instances = { 1200, 1207, 1208 }, encounters = { 2493, 2523, 2563 } }, -- Dreadful Synchronous Timestrand
    [217333] = { slot = 3, classMask = 1156, instances = { 1200, 1207, 1208 }, encounters = { 2493, 2523, 2563 } }, -- Mystic Synchronous Timestrand
    [217334] = { slot = 3, classMask = 82, instances = { 1200, 1207, 1208 }, encounters = { 2493, 2523, 2563 } }, -- Venerated Synchronous Timestrand
    [217335] = { slot = 3, classMask = 4617, instances = { 1200, 1207, 1208 }, encounters = { 2493, 2523, 2563 } }, -- Zenith Synchronous Timestrand
    [225614] = { slot = 5, classMask = 2336, instances = { 1273 }, encounters = { 2612 } }, -- Dreadful Blasphemer's Effigy
    [225615] = { slot = 5, classMask = 1156, instances = { 1273 }, encounters = { 2612 } }, -- Mystic Blasphemer's Effigy
    [225616] = { slot = 5, classMask = 82, instances = { 1273 }, encounters = { 2612 } }, -- Venerated Blasphemer's Effigy
    [225617] = { slot = 5, classMask = 4617, instances = { 1273 }, encounters = { 2612 } }, -- Zenith Blasphemer's Effigy
    [225618] = { slot = 10, classMask = 2336, instances = { 1273 }, encounters = { 2599 } }, -- Dreadful Stalwart's Emblem
    [225619] = { slot = 10, classMask = 1156, instances = { 1273 }, encounters = { 2599 } }, -- Mystic Stalwart's Emblem
    [225620] = { slot = 10, classMask = 82, instances = { 1273 }, encounters = { 2599 } }, -- Venerated Stalwart's Emblem
    [225621] = { slot = 10, classMask = 4617, instances = { 1273 }, encounters = { 2599 } }, -- Zenith Stalwart's Emblem
    [225622] = { slot = 1, classMask = 2336, instances = { 1273 }, encounters = { 2608 } }, -- Dreadful Conniver's Badge
    [225623] = { slot = 1, classMask = 1156, instances = { 1273 }, encounters = { 2608 } }, -- Mystic Conniver's Badge
    [225624] = { slot = 1, classMask = 82, instances = { 1273 }, encounters = { 2608 } }, -- Venerated Conniver's Badge
    [225625] = { slot = 1, classMask = 4617, instances = { 1273 }, encounters = { 2608 } }, -- Zenith Conniver's Badge
    [225626] = { slot = 7, classMask = 2336, instances = { 1273 }, encounters = { 2601 } }, -- Dreadful Slayer's Icon
    [225627] = { slot = 7, classMask = 1156, instances = { 1273 }, encounters = { 2601 } }, -- Mystic Slayer's Icon
    [225628] = { slot = 7, classMask = 82, instances = { 1273 }, encounters = { 2601 } }, -- Venerated Slayer's Icon
    [225629] = { slot = 7, classMask = 4617, instances = { 1273 }, encounters = { 2601 } }, -- Zenith Slayer's Icon
    [225630] = { slot = 3, classMask = 2336, instances = { 1273 }, encounters = { 2609 } }, -- Dreadful Obscenity's Idol
    [225631] = { slot = 3, classMask = 1156, instances = { 1273 }, encounters = { 2609 } }, -- Mystic Obscenity's Idol
    [225632] = { slot = 3, classMask = 82, instances = { 1273 }, encounters = { 2609 } }, -- Venerated Obscenity's Idol
    [225633] = { slot = 3, classMask = 4617, instances = { 1273 }, encounters = { 2609 } }, -- Zenith Obscenity's Idol
    [228799] = { slot = 5, classMask = 2336, instances = { 1296 }, encounters = { 2653 } }, -- Dreadful Greased Gallybux
    [228800] = { slot = 5, classMask = 1156, instances = { 1296 }, encounters = { 2653 } }, -- Mystic Greased Gallybux
    [228801] = { slot = 5, classMask = 82, instances = { 1296 }, encounters = { 2653 } }, -- Venerated Greased Gallybux
    [228802] = { slot = 5, classMask = 4617, instances = { 1296 }, encounters = { 2653 } }, -- Zenith Greased Gallybux
    [228803] = { slot = 10, classMask = 2336, instances = { 1296 }, encounters = { 2640 } }, -- Dreadful Bloody Gallybux
    [228804] = { slot = 10, classMask = 1156, instances = { 1296 }, encounters = { 2640 } }, -- Mystic Bloody Gallybux
    [228805] = { slot = 10, classMask = 82, instances = { 1296 }, encounters = { 2640 } }, -- Venerated Bloody Gallybux
    [228806] = { slot = 10, classMask = 4617, instances = { 1296 }, encounters = { 2640 } }, -- Zenith Bloody Gallybux
    [228807] = { slot = 1, classMask = 2336, instances = { 1296 }, encounters = { 2644 } }, -- Dreadful Gilded Gallybux
    [228808] = { slot = 1, classMask = 1156, instances = { 1296 }, encounters = { 2644 } }, -- Mystic Gilded Gallybux
    [228809] = { slot = 1, classMask = 82, instances = { 1296 }, encounters = { 2644 } }, -- Venerated Gilded Gallybux
    [228810] = { slot = 1, classMask = 4617, instances = { 1296 }, encounters = { 2644 } }, -- Zenith Gilded Gallybux
    [228811] = { slot = 7, classMask = 2336, instances = { 1296 }, encounters = { 2642 } }, -- Dreadful Rusty Gallybux
    [228812] = { slot = 7, classMask = 1156, instances = { 1296 }, encounters = { 2642 } }, -- Mystic Rusty Gallybux
    [228813] = { slot = 7, classMask = 82, instances = { 1296 }, encounters = { 2642 } }, -- Venerated Rusty Gallybux
    [228814] = { slot = 7, classMask = 4617, instances = { 1296 }, encounters = { 2642 } }, -- Zenith Rusty Gallybux
    [228815] = { slot = 3, classMask = 2336, instances = { 1296 }, encounters = { 2641 } }, -- Dreadful Polished Gallybux
    [228816] = { slot = 3, classMask = 1156, instances = { 1296 }, encounters = { 2641 } }, -- Mystic Polished Gallybux
    [228817] = { slot = 3, classMask = 82, instances = { 1296 }, encounters = { 2641 } }, -- Venerated Polished Gallybux
    [228818] = { slot = 3, classMask = 4617, instances = { 1296 }, encounters = { 2641 } }, -- Zenith Polished Gallybux
    [237581] = { slot = 5, classMask = 2336, instances = { 1302 }, encounters = { 2747 } }, -- Dreadful Voidglass Contaminant
    [237582] = { slot = 5, classMask = 1156, instances = { 1302 }, encounters = { 2747 } }, -- Mystic Voidglass Contaminant
    [237583] = { slot = 5, classMask = 82, instances = { 1302 }, encounters = { 2747 } }, -- Venerated Voidglass Contaminant
    [237584] = { slot = 5, classMask = 4617, instances = { 1302 }, encounters = { 2747 } }, -- Zenith Voidglass Contaminant
    [237585] = { slot = 10, classMask = 2336, instances = { 1302 }, encounters = { 2685 } }, -- Dreadful Binding Agent
    [237586] = { slot = 10, classMask = 1156, instances = { 1302 }, encounters = { 2685 } }, -- Mystic Binding Agent
    [237587] = { slot = 10, classMask = 82, instances = { 1302 }, encounters = { 2685 } }, -- Venerated Binding Agent
    [237588] = { slot = 10, classMask = 4617, instances = { 1302 }, encounters = { 2685 } }, -- Zenith Binding Agent
    [237589] = { slot = 1, classMask = 2336, instances = { 1302 }, encounters = { 2687 } }, -- Dreadful Foreboding Beaker
    [237590] = { slot = 1, classMask = 1156, instances = { 1302 }, encounters = { 2687 } }, -- Mystic Foreboding Beaker
    [237591] = { slot = 1, classMask = 82, instances = { 1302 }, encounters = { 2687 } }, -- Venerated Foreboding Beaker
    [237592] = { slot = 1, classMask = 4617, instances = { 1302 }, encounters = { 2687 } }, -- Zenith Foreboding Beaker
    [237593] = { slot = 7, classMask = 2336, instances = { 1302 }, encounters = { 2686 } }, -- Dreadful Silken Offering
    [237594] = { slot = 7, classMask = 1156, instances = { 1302 }, encounters = { 2686 } }, -- Mystic Silken Offering
    [237595] = { slot = 7, classMask = 82, instances = { 1302 }, encounters = { 2686 } }, -- Venerated Silken Offering
    [237596] = { slot = 7, classMask = 4617, instances = { 1302 }, encounters = { 2686 } }, -- Zenith Silken Offering
    [237597] = { slot = 3, classMask = 2336, instances = { 1302 }, encounters = { 2688 } }, -- Dreadful Yearning Cursemark
    [237598] = { slot = 3, classMask = 1156, instances = { 1302 }, encounters = { 2688 } }, -- Mystic Yearning Cursemark
    [237599] = { slot = 3, classMask = 82, instances = { 1302 }, encounters = { 2688 } }, -- Venerated Yearning Cursemark
    [237600] = { slot = 3, classMask = 4617, instances = { 1302 }, encounters = { 2688 } }, -- Zenith Yearning Cursemark
    [249347] = { slot = 5, classMask = 400, instances = { 1314 }, encounters = { 2795 } }, -- Alnwoven Riftbloom
    [249348] = { slot = 5, classMask = 3592, instances = { 1314 }, encounters = { 2795 } }, -- Alncured Riftbloom
    [249349] = { slot = 5, classMask = 4164, instances = { 1314 }, encounters = { 2795 } }, -- Alncast Riftbloom
    [249350] = { slot = 5, classMask = 35, instances = { 1314 }, encounters = { 2795 } }, -- Alnforged Riftbloom
    [249351] = { slot = 10, classMask = 400, instances = { 1307 }, encounters = { 2734 } }, -- Voidwoven Hungering Nullcore
    [249352] = { slot = 10, classMask = 3592, instances = { 1307 }, encounters = { 2734 } }, -- Voidcured Hungering Nullcore
    [249353] = { slot = 10, classMask = 4164, instances = { 1307 }, encounters = { 2734 } }, -- Voidcast Hungering Nullcore
    [249354] = { slot = 10, classMask = 35, instances = { 1307 }, encounters = { 2734 } }, -- Voidforged Hungering Nullcore
    [249355] = { slot = 1, classMask = 400, instances = { 1307 }, encounters = { 2737 } }, -- Voidwoven Fanatical Nullcore
    [249356] = { slot = 1, classMask = 3592, instances = { 1307 }, encounters = { 2737 } }, -- Voidcured Fanatical Nullcore
    [249357] = { slot = 1, classMask = 4164, instances = { 1307 }, encounters = { 2737 } }, -- Voidcast Fanatical Nullcore
    [249358] = { slot = 1, classMask = 35, instances = { 1307 }, encounters = { 2737 } }, -- Voidforged Fanatical Nullcore
    [249359] = { slot = 7, classMask = 400, instances = { 1307 }, encounters = { 2735 } }, -- Voidwoven Corrupted Nullcore
    [249360] = { slot = 7, classMask = 3592, instances = { 1307 }, encounters = { 2735 } }, -- Voidcured Corrupted Nullcore
    [249361] = { slot = 7, classMask = 4164, instances = { 1307 }, encounters = { 2735 } }, -- Voidcast Corrupted Nullcore
    [249362] = { slot = 7, classMask = 35, instances = { 1307 }, encounters = { 2735 } }, -- Voidforged Corrupted Nullcore
    [249363] = { slot = 3, classMask = 400, instances = { 1307 }, encounters = { 2736 } }, -- Voidwoven Unraveled Nullcore
    [249364] = { slot = 3, classMask = 3592, instances = { 1307 }, encounters = { 2736 } }, -- Voidcured Unraveled Nullcore
    [249365] = { slot = 3, classMask = 4164, instances = { 1307 }, encounters = { 2736 } }, -- Voidcast Unraveled Nullcore
    [249366] = { slot = 3, classMask = 35, instances = { 1307 }, encounters = { 2736 } }, -- Voidforged Unraveled Nullcore
    [270910] = { slot = 10, classMask = 400, instances = { 1320 }, encounters = { 2874 } }, -- Venomwoven Idol
    [270911] = { slot = 10, classMask = 3592, instances = { 1320 }, encounters = { 2874 } }, -- Venomcured Idol
    [270912] = { slot = 10, classMask = 4164, instances = { 1320 }, encounters = { 2874 } }, -- Venomcast Idol
    [270913] = { slot = 10, classMask = 35, instances = { 1320 }, encounters = { 2874 } }, -- Venomforged Idol
    [270914] = { slot = 1, classMask = 400, instances = { 1320 }, encounters = { 2887 } }, -- Venomwoven Effigy
    [270915] = { slot = 1, classMask = 3592, instances = { 1320 }, encounters = { 2887 } }, -- Venomcured Effigy
    [270916] = { slot = 1, classMask = 4164, instances = { 1320 }, encounters = { 2887 } }, -- Venomcast Effigy
    [270917] = { slot = 1, classMask = 35, instances = { 1320 }, encounters = { 2887 } }, -- Venomforged Effigy
    [270918] = { slot = 7, classMask = 400, instances = { 1320 }, encounters = { 2871 } }, -- Venomwoven Relic
    [270919] = { slot = 7, classMask = 3592, instances = { 1320 }, encounters = { 2871 } }, -- Venomcured Relic
    [270920] = { slot = 7, classMask = 4164, instances = { 1320 }, encounters = { 2871 } }, -- Venomcast Relic
    [270921] = { slot = 7, classMask = 35, instances = { 1320 }, encounters = { 2871 } }, -- Venomforged Relic
    [270922] = { slot = 3, classMask = 400, instances = { 1320 }, encounters = { 2894 } }, -- Venomwoven Remnant
    [270923] = { slot = 3, classMask = 3592, instances = { 1320 }, encounters = { 2894 } }, -- Venomcured Remnant
    [270924] = { slot = 3, classMask = 4164, instances = { 1320 }, encounters = { 2894 } }, -- Venomcast Remnant
    [270925] = { slot = 3, classMask = 35, instances = { 1320 }, encounters = { 2894 } }, -- Venomforged Remnant
    [270926] = { slot = 5, classMask = 400, instances = { 1320 }, encounters = { 2882 } }, -- Venomwoven Icon
    [270927] = { slot = 5, classMask = 3592, instances = { 1320 }, encounters = { 2882 } }, -- Venomcured Icon
    [270928] = { slot = 5, classMask = 4164, instances = { 1320 }, encounters = { 2882 } }, -- Venomcast Icon
    [270929] = { slot = 5, classMask = 35, instances = { 1320 }, encounters = { 2882 } }, -- Venomforged Icon
}
