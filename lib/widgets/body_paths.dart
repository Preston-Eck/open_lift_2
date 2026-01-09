import 'dart:ui';

/// A collection of normalized paths (0..100 x 0..100) for a "Low Poly" muscle map.
class BodyPaths {
  
  // --- FRONT ---
  
  static Path get chestLeft {
    return Path()
      ..moveTo(50, 25)
      ..lineTo(25, 22) // Shoulder connection
      ..lineTo(28, 35) // Armpit
      ..lineTo(50, 40) // Sternum bottom
      ..close();
  }
  static Path get chestRight {
    return Path()
      ..moveTo(50, 25)
      ..lineTo(75, 22)
      ..lineTo(72, 35)
      ..lineTo(50, 40)
      ..close();
  }

  static Path get absUpper {
    return Path()
      ..moveTo(50, 40)
      ..lineTo(35, 38)
      ..lineTo(38, 55)
      ..lineTo(50, 58)
      ..lineTo(62, 55)
      ..lineTo(65, 38)
      ..close();
  }

  static Path get absLower {
    return Path()
      ..moveTo(50, 58)
      ..lineTo(38, 55)
      ..lineTo(40, 65)
      ..lineTo(50, 68) // Pubic bone
      ..lineTo(60, 65)
      ..lineTo(62, 55)
      ..close();
  }

  static Path get shoulderLeft {
    return Path()
      ..moveTo(25, 22)
      ..lineTo(10, 25)
      ..lineTo(8, 35)
      ..lineTo(28, 35)
      ..close();
  }
  static Path get shoulderRight {
    return Path()
      ..moveTo(75, 22)
      ..lineTo(90, 25)
      ..lineTo(92, 35)
      ..lineTo(72, 35)
      ..close();
  }

  static Path get bicepLeft {
    return Path()
      ..moveTo(28, 35)
      ..lineTo(8, 35)
      ..lineTo(10, 45)
      ..lineTo(25, 42)
      ..close();
  }
  static Path get bicepRight {
    return Path()
      ..moveTo(72, 35)
      ..lineTo(92, 35)
      ..lineTo(90, 45)
      ..lineTo(75, 42)
      ..close();
  }

  static Path get forearmsLeft {
    return Path()..addRect(const Rect.fromLTWH(5, 45, 15, 20)); // Simplified
  }
  static Path get forearmsRight {
    return Path()..addRect(const Rect.fromLTWH(80, 45, 15, 20));
  }

  static Path get quadsLeft {
    return Path()
      ..moveTo(40, 65)
      ..lineTo(20, 60) // Hip
      ..lineTo(18, 90) // Knee out
      ..lineTo(30, 95) // Knee in
      ..lineTo(48, 70) // Groin
      ..close();
  }
  static Path get quadsRight {
    return Path()
      ..moveTo(60, 65)
      ..lineTo(80, 60)
      ..lineTo(82, 90)
      ..lineTo(70, 95)
      ..lineTo(52, 70)
      ..close();
  }
  
  static Path get calvesLeft {
    return Path()..moveTo(18, 95)..lineTo(30, 95)..lineTo(28, 120)..lineTo(20, 120)..close();
  }
  static Path get calvesRight {
    return Path()..moveTo(82, 95)..lineTo(70, 95)..lineTo(72, 120)..lineTo(80, 120)..close();
  }

  // --- BACK ---

  static Path get traps {
    return Path()
      ..moveTo(50, 15) // Neck base
      ..lineTo(25, 22) // Shoulder L
      ..lineTo(50, 35) // Mid back
      ..lineTo(75, 22) // Shoulder R
      ..close();
  }

  static Path get latsLeft {
    return Path()
      ..moveTo(50, 35)
      ..lineTo(25, 22)
      ..lineTo(28, 45) // Waist L
      ..lineTo(50, 55) // Lower back center
      ..close();
  }
  static Path get latsRight {
    return Path()
      ..moveTo(50, 35)
      ..lineTo(75, 22)
      ..lineTo(72, 45)
      ..lineTo(50, 55)
      ..close();
  }

  static Path get glutesLeft {
    return Path()
      ..moveTo(50, 55)
      ..lineTo(28, 45)
      ..lineTo(20, 60)
      ..lineTo(50, 68)
      ..close();
  }
  static Path get glutesRight {
    return Path()
      ..moveTo(50, 55)
      ..lineTo(72, 45)
      ..lineTo(80, 60)
      ..lineTo(50, 68)
      ..close();
  }

  static Path get hamsLeft {
    return Path()
      ..moveTo(20, 60)
      ..lineTo(50, 68)
      ..lineTo(48, 70)
      ..lineTo(30, 95)
      ..lineTo(18, 90)
      ..close();
  }
  static Path get hamsRight {
    return Path()
      ..moveTo(80, 60)
      ..lineTo(50, 68)
      ..lineTo(52, 70)
      ..lineTo(70, 95)
      ..lineTo(82, 90)
      ..close();
  }
  
  static Path get tricepsLeft {
    return Path()..moveTo(25, 22)..lineTo(8, 35)..lineTo(10, 45)..lineTo(25, 42)..close();
  }
  static Path get tricepsRight {
    return Path()..moveTo(75, 22)..lineTo(92, 35)..lineTo(90, 45)..lineTo(75, 42)..close();
  }
}
