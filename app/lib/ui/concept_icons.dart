import 'package:flutter/material.dart';
import '../models/storytime_models.dart';

/// Rich, multi-color storybook icons for the story-creation vocabulary
/// (characters, scenes, themes, plots, narrators).
///
/// Design rules that make the set "talk" with the app theme:
///   - one warm ink outline (`#7A4A14` / `#2A2230`) across every glyph,
///   - a jewel-tone palette pulled from `StoryTheme.color`,
///   - each glyph seated on a cream-based [tint] token (see [StConceptToken]).
///
/// Icons are authored as inline SVG strings rendered with `flutter_svg`.
/// Concepts not yet drawn return `null`; callers fall back to the enum emoji
/// so the app stays whole while the set is completed.
class ConceptIcon {
  const ConceptIcon(this.svg, this.tint);

  /// Inline SVG (viewBox `0 0 48 48`).
  final String svg;

  /// Cream-based token background behind the glyph.
  final Color tint;
}

// --- token tints (warm, cream-based, low-saturation) ---
const _tGold = Color(0xFFF6E7C9);
const _tCoral = Color(0xFFFBE0D6);
const _tTeal = Color(0xFFD6EFE6);
const _tLavender = Color(0xFFE7E1FB);
const _tPeach = Color(0xFFFBE6CE);
const _tPink = Color(0xFFFBDDE7);
const _tBlue = Color(0xFFD9EAFB);
const _tYellow = Color(0xFFFBEFC9);
const _tRose = Color(0xFFFBE0EC);
const _tFire = Color(0xFFFCDCD0);
const _tPeri = Color(0xFFE6E6FA);
const _tAqua = Color(0xFFD6EEF1);
const _tGreen = Color(0xFFE3F0DA);
const _tSlate = Color(0xFFE7EAF1);
const _tBarn = Color(0xFFFBEAD2);
const _tNight = Color(0xFFE5E2F4);
const _tSky = Color(0xFFDDEAF6);
const _tMyst = Color(0xFFE8E4F2);
const _tStorm = Color(0xFFEAE5F2);
const _tGift = Color(0xFFEDE6FA);
const _tPuzzle = Color(0xFFDFF0EB);
const _tFairy = Color(0xFFE7F1E3);

/// Neutral cream token for concepts not yet drawn (emoji fallback).
const _tNeutral = Color(0xFFF4ECDE);

/// The token / card background for a concept. Falls back to a soft neutral
/// cream so undrawn concepts (and the family-voice card) still read as tokens.
Color conceptTintFor(Object? value) {
  if (value == null) return _tNeutral;
  return conceptIconFor(value)?.tint ?? _tNeutral;
}

/// Returns the rich icon for a story-vocabulary [value], or `null` if it has
/// not been drawn yet (caller should fall back to the emoji).
ConceptIcon? conceptIconFor(Object value) => switch (value) {
  // Characters
  StoryCharacter.prince => const ConceptIcon(_crown, _tGold),
  StoryCharacter.princess => const ConceptIcon(_tiara, _tRose),
  StoryCharacter.doctor => const ConceptIcon(_stethoscope, _tCoral),
  StoryCharacter.builder => const ConceptIcon(_hardHat, _tYellow),
  StoryCharacter.firefighter => const ConceptIcon(_fireHelmet, _tFire),
  StoryCharacter.animalFriend => const ConceptIcon(_fox, _tTeal),
  // Scenes
  StoryScene.castle => const ConceptIcon(_castle, _tLavender),
  StoryScene.space => const ConceptIcon(_rocket, _tPeri),
  StoryScene.underTheSea => const ConceptIcon(_fish, _tAqua),
  StoryScene.forest => const ConceptIcon(_pine, _tGreen),
  StoryScene.city => const ConceptIcon(_city, _tSlate),
  StoryScene.farm => const ConceptIcon(_barn, _tBarn),
  // Themes
  StoryTheme.friendship => const ConceptIcon(_friendship, _tPink),
  StoryTheme.bravery => const ConceptIcon(_lion, _tGold),
  StoryTheme.bedtime => const ConceptIcon(_moon, _tNight),
  StoryTheme.adventure => const ConceptIcon(_compass, _tSky),
  StoryTheme.mystery => const ConceptIcon(_magnifier, _tMyst),
  StoryTheme.kindness => const ConceptIcon(_kindHeart, _tBarn),
  // Plots
  StoryPlot.somethingGoesWrong => const ConceptIcon(_bolt, _tStorm),
  StoryPlot.surpriseFriend => const ConceptIcon(_gift, _tGift),
  StoryPlot.treasureHunt => const ConceptIcon(_treasure, _tPeach),
  StoryPlot.problemToSolve => const ConceptIcon(_puzzle, _tPuzzle),
  StoryPlot.bigWin => const ConceptIcon(_trophy, _tYellow),
  StoryPlot.magicMoment => const ConceptIcon(_magic, _tBlue),
  // Narrators
  NarratorKey.wizardWally => const ConceptIcon(_wizardHat, _tLavender),
  NarratorKey.fairyFern => const ConceptIcon(_fairy, _tFairy),
  NarratorKey.roboRay => const ConceptIcon(_robot, _tBlue),
  _ => null,
};

const String _crown =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path d="M7 33 L7 16 L16 24 L24 11 L32 24 L41 16 L41 33 Z" fill="#F2B23E" stroke="#7A4A14" stroke-width="2.2" stroke-linejoin="round"/>'
    '<rect x="7" y="32" width="34" height="7" rx="2.5" fill="#E0911F" stroke="#7A4A14" stroke-width="2.2"/>'
    '<circle cx="24" cy="19" r="2.6" fill="#E2575B"/>'
    '<circle cx="14.5" cy="26" r="2" fill="#3FB59A"/>'
    '<circle cx="33.5" cy="26" r="2" fill="#8B7CF6"/>'
    '</svg>';

const String _stethoscope =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<circle cx="15" cy="11" r="2.6" fill="#2A2230"/>'
    '<circle cx="33" cy="11" r="2.6" fill="#2A2230"/>'
    '<path d="M15 13 V21 a9 9 0 0 0 18 0 V13" fill="none" stroke="#E2575B" stroke-width="3.4" stroke-linecap="round"/>'
    '<path d="M24 30 V35" fill="none" stroke="#E2575B" stroke-width="3.4" stroke-linecap="round"/>'
    '<circle cx="24" cy="39" r="5" fill="#C9CDD6" stroke="#7A4A14" stroke-width="2"/>'
    '<circle cx="24" cy="39" r="1.8" fill="#7E8593"/>'
    '</svg>';

const String _fox =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path d="M11 11 L19 23 L7 25 Z" fill="#F18A3E" stroke="#7A4A14" stroke-width="2" stroke-linejoin="round"/>'
    '<path d="M37 11 L29 23 L41 25 Z" fill="#F18A3E" stroke="#7A4A14" stroke-width="2" stroke-linejoin="round"/>'
    '<path d="M9 22 Q24 16 39 22 L24 41 Z" fill="#F7A24E" stroke="#7A4A14" stroke-width="2.2" stroke-linejoin="round"/>'
    '<path d="M16 29 Q24 27 32 29 L24 41 Z" fill="#FBF6EE"/>'
    '<circle cx="18.5" cy="27" r="1.9" fill="#2A2230"/>'
    '<circle cx="29.5" cy="27" r="1.9" fill="#2A2230"/>'
    '<path d="M24 33 l3 0 -3 3 -3 -3 Z" fill="#2A2230"/>'
    '</svg>';

const String _castle =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<rect x="9" y="20" width="30" height="20" fill="#9B8CF6" stroke="#5B4FB0" stroke-width="2.2"/>'
    '<rect x="7" y="16" width="9" height="24" fill="#8B7CF6" stroke="#5B4FB0" stroke-width="2.2"/>'
    '<rect x="32" y="16" width="9" height="24" fill="#8B7CF6" stroke="#5B4FB0" stroke-width="2.2"/>'
    '<path d="M20 40 V30 a4 4 0 0 1 8 0 V40 Z" fill="#5B4FB0"/>'
    '<path d="M24 9 l6 2 -6 2 Z" fill="#E2575B"/>'
    '<path d="M11 12 l5 1.6 -5 1.6 Z" fill="#3FB59A"/>'
    '<path d="M37 12 l-5 1.6 5 1.6 Z" fill="#3FB59A"/>'
    '</svg>';

const String _treasure =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<rect x="9" y="22" width="30" height="17" rx="3" fill="#B5722E" stroke="#6E3F14" stroke-width="2.2"/>'
    '<path d="M9 24 a15 8 0 0 1 30 0 Z" fill="#C8843B" stroke="#6E3F14" stroke-width="2.2"/>'
    '<rect x="9" y="26" width="30" height="4" fill="#E0A24A"/>'
    '<ellipse cx="24" cy="22" rx="13" ry="4" fill="#F2C84B" stroke="#6E3F14" stroke-width="1.6"/>'
    '<circle cx="18" cy="21" r="2.2" fill="#E2575B"/>'
    '<circle cx="24" cy="20" r="2.4" fill="#3FB59A"/>'
    '<circle cx="30" cy="21" r="2.2" fill="#8B7CF6"/>'
    '<rect x="22" y="31" width="4" height="5" rx="1" fill="#F2C84B" stroke="#6E3F14" stroke-width="1.4"/>'
    '</svg>';

const String _magic =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path d="M24 6 C18 16 13 18 13 26 a11 11 0 0 0 22 0 c0-8 -5-10 -11-20 Z" fill="#4FA3E8" stroke="#1E5C96" stroke-width="2.2" stroke-linejoin="round"/>'
    '<path d="M24 16 C21 22 18 22 18 27 a6 6 0 0 0 4 5" fill="none" stroke="#BFE0FA" stroke-width="2.4" stroke-linecap="round"/>'
    '</svg>';

const String _trophy =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path d="M16 28 a8 8 0 1 1 16 0 Z" fill="#F2C84B" stroke="#7A4A14" stroke-width="2.2"/>'
    '<rect x="14" y="27" width="20" height="5" rx="2" fill="#E0911F" stroke="#7A4A14" stroke-width="2"/>'
    '<path d="M24 6 V12 M11 11 L15 15 M37 11 L33 15 M7 24 H13 M41 24 H35" stroke="#F2A93E" stroke-width="2.6" stroke-linecap="round"/>'
    '<circle cx="24" cy="24" r="4" fill="#FBE08A"/>'
    '</svg>';

const String _friendship =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path d="M18 38 C7 30 6 21 12 18 c4-2 6 1 6 3 c0-2 2-5 6-3 c6 3 5 12 -6 20 Z" fill="#E2575B" stroke="#9C2F3C" stroke-width="2"/>'
    '<path d="M30 40 C19 32 18 23 24 20 c4-2 6 1 6 3 c0-2 2-5 6-3 c6 3 5 12 -6 20 Z" fill="#8B7CF6" stroke="#5B4FB0" stroke-width="2"/>'
    '</svg>';

const String _tiara =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path d="M8 32 L13 21 L18 28 L24 17 L30 28 L35 21 L40 32 Z" fill="#F4A6C8" stroke="#C03E76" stroke-width="2.2" stroke-linejoin="round"/>'
    '<rect x="8" y="31" width="32" height="6" rx="2.5" fill="#E97FB0" stroke="#C03E76" stroke-width="2.2"/>'
    '<circle cx="24" cy="24" r="2.6" fill="#E2575B"/>'
    '<circle cx="14" cy="26" r="1.7" fill="#8B7CF6"/>'
    '<circle cx="34" cy="26" r="1.7" fill="#3FB59A"/>'
    '</svg>';

const String _hardHat =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<rect x="21" y="14" width="6" height="12" rx="2" fill="#E0A21F"/>'
    '<path d="M9 31 a15 13 0 0 1 30 0 Z" fill="#F2C03E" stroke="#9A6A12" stroke-width="2.2" stroke-linejoin="round"/>'
    '<rect x="6" y="30" width="36" height="5" rx="2.5" fill="#E0A21F" stroke="#9A6A12" stroke-width="2.2"/>'
    '</svg>';

const String _fireHelmet =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path d="M8 33 Q9 21 24 20 Q39 21 40 33 Z" fill="#E2483C" stroke="#9A2018" stroke-width="2.2" stroke-linejoin="round"/>'
    '<path d="M6 33 q18 6 36 0" fill="none" stroke="#9A2018" stroke-width="2.2"/>'
    '<path d="M20 33 L24 15 L28 33 Z" fill="#F2C84B" stroke="#9A2018" stroke-width="1.6" stroke-linejoin="round"/>'
    '<circle cx="24" cy="27" r="2.4" fill="#E2483C" stroke="#9A2018" stroke-width="1.2"/>'
    '</svg>';

const String _rocket =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path d="M24 6 C30 13 30 24 27 31 H21 C18 24 18 13 24 6 Z" fill="#EDEEF3" stroke="#5B4FB0" stroke-width="2.2" stroke-linejoin="round"/>'
    '<circle cx="24" cy="18" r="3.4" fill="#4FA3E8" stroke="#1E5C96" stroke-width="1.6"/>'
    '<path d="M21 28 L15 34 L21 32 Z" fill="#E2575B" stroke="#9C2F3C" stroke-width="1.4" stroke-linejoin="round"/>'
    '<path d="M27 28 L33 34 L27 32 Z" fill="#E2575B" stroke="#9C2F3C" stroke-width="1.4" stroke-linejoin="round"/>'
    '<path d="M21 31 Q24 40 27 31 Z" fill="#F2A93E"/>'
    '</svg>';

const String _fish =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<ellipse cx="22" cy="26" rx="13" ry="9" fill="#2BB7C4" stroke="#15727C" stroke-width="2.2"/>'
    '<path d="M33 26 L42 19 L40 26 L42 33 Z" fill="#2BB7C4" stroke="#15727C" stroke-width="2.2" stroke-linejoin="round"/>'
    '<circle cx="16" cy="23" r="2.4" fill="#FBF6EE" stroke="#15727C" stroke-width="1"/>'
    '<circle cx="15.4" cy="23" r="1.1" fill="#2A2230"/>'
    '<path d="M22 21 q3 5 0 10" fill="none" stroke="#15727C" stroke-width="1.2"/>'
    '<circle cx="9" cy="13" r="1.6" fill="#9FE0E6"/>'
    '<circle cx="13" cy="8" r="1.1" fill="#9FE0E6"/>'
    '</svg>';

const String _pine =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<rect x="21" y="31" width="6" height="9" fill="#9A6A3A" stroke="#5E3F1E" stroke-width="1.6"/>'
    '<path d="M24 7 L33 21 H15 Z" fill="#4FA64E" stroke="#2E6E2C" stroke-width="2" stroke-linejoin="round"/>'
    '<path d="M24 16 L36 32 H12 Z" fill="#3F9A44" stroke="#2E6E2C" stroke-width="2" stroke-linejoin="round"/>'
    '</svg>';

const String _city =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<rect x="8" y="20" width="9" height="19" fill="#8B7CF6" stroke="#5B4FB0" stroke-width="1.8"/>'
    '<rect x="19" y="13" width="10" height="26" fill="#E2575B" stroke="#9C2F3C" stroke-width="1.8"/>'
    '<rect x="31" y="24" width="9" height="15" fill="#3FB59A" stroke="#15727C" stroke-width="1.8"/>'
    '<g fill="#FBE08A">'
    '<rect x="22" y="17" width="2.2" height="2.2"/><rect x="25.5" y="17" width="2.2" height="2.2"/>'
    '<rect x="22" y="22" width="2.2" height="2.2"/><rect x="25.5" y="22" width="2.2" height="2.2"/>'
    '<rect x="11" y="24" width="2.2" height="2.2"/><rect x="11" y="29" width="2.2" height="2.2"/>'
    '<rect x="34" y="28" width="2.2" height="2.2"/><rect x="34" y="33" width="2.2" height="2.2"/>'
    '</g>'
    '</svg>';

const String _barn =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<rect x="10" y="22" width="28" height="17" fill="#E2483C" stroke="#9A2018" stroke-width="2.2"/>'
    '<path d="M8 23 L24 12 L40 23 Z" fill="#C0392E" stroke="#9A2018" stroke-width="2.2" stroke-linejoin="round"/>'
    '<rect x="20" y="29" width="8" height="10" fill="#F4E9D6" stroke="#9A2018" stroke-width="1.6"/>'
    '<path d="M24 29 V39 M20 34 H28" stroke="#C0392E" stroke-width="1.3"/>'
    '</svg>';

const String _lion =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<circle cx="24" cy="25" r="14" fill="#E0911F" stroke="#9A6A12" stroke-width="2"/>'
    '<circle cx="24" cy="25" r="10" fill="#F2C24E" stroke="#9A6A12" stroke-width="1.6"/>'
    '<circle cx="20" cy="23" r="1.7" fill="#2A2230"/>'
    '<circle cx="28" cy="23" r="1.7" fill="#2A2230"/>'
    '<path d="M24 27 l2.6 0 -2.6 2.8 -2.6 -2.8 Z" fill="#7A4A14"/>'
    '<path d="M24 29.8 V32 M24 32 q-3 1.5 -4.5 -0.8 M24 32 q3 1.5 4.5 -0.8" fill="none" stroke="#7A4A14" stroke-width="1.3" stroke-linecap="round"/>'
    '</svg>';

const String _moon =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path d="M28 7 a14 14 0 1 0 6 27 A11 11 0 0 1 28 7 Z" fill="#F2D24B" stroke="#C9A23A" stroke-width="2.2" stroke-linejoin="round"/>'
    '<path d="M15 13 l1.2 3 3 1.2 -3 1.2 -1.2 3 -1.2 -3 -3 -1.2 3 -1.2 Z" fill="#FBE08A"/>'
    '<circle cx="16" cy="31" r="1.4" fill="#FBE08A"/>'
    '</svg>';

const String _compass =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<circle cx="24" cy="24" r="15" fill="#EDF2F8" stroke="#1E5C96" stroke-width="2.4"/>'
    '<path d="M24 11 L27 24 L21 24 Z" fill="#E2575B" stroke="#9C2F3C" stroke-width="1" stroke-linejoin="round"/>'
    '<path d="M24 37 L21 24 L27 24 Z" fill="#C9CDD6" stroke="#7E8593" stroke-width="1" stroke-linejoin="round"/>'
    '<circle cx="24" cy="24" r="1.9" fill="#2A2230"/>'
    '</svg>';

const String _magnifier =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<line x1="29" y1="29" x2="39" y2="39" stroke="#5B4FB0" stroke-width="4.4" stroke-linecap="round"/>'
    '<circle cx="21" cy="21" r="11" fill="#DCE7FB" stroke="#5B4FB0" stroke-width="3"/>'
    '<path d="M18 17 a3.6 3.6 0 0 1 6 2.6 c0 2.8 -3 2.2 -3 4.6" fill="none" stroke="#7A6FC0" stroke-width="2" stroke-linecap="round"/>'
    '<circle cx="21" cy="27" r="1.3" fill="#7A6FC0"/>'
    '</svg>';

const String _kindHeart =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path d="M24 14 C22 10 16 10 16 15 c0 4 8 10 8 10 c0 0 8-6 8-10 c0-5 -6-5 -8-1 Z" fill="#F2C84B" stroke="#C9881A" stroke-width="2" stroke-linejoin="round"/>'
    '<path d="M11 27 C11 36 37 36 37 27 L37 31 C37 39 11 39 11 31 Z" fill="#F2B98C" stroke="#C77E4A" stroke-width="1.8" stroke-linejoin="round"/>'
    '</svg>';

const String _bolt =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path d="M13 23 a7 7 0 0 1 1 -13 a9 9 0 0 1 17 2 a6 6 0 0 1 -1 11 Z" fill="#C9CDD6" stroke="#8A90A0" stroke-width="2" stroke-linejoin="round"/>'
    '<path d="M25 17 L18 30 H23 L20 41 L31 26 H25 L29 17 Z" fill="#F2C03E" stroke="#B9851A" stroke-width="2" stroke-linejoin="round"/>'
    '</svg>';

const String _gift =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<rect x="9" y="22" width="30" height="17" rx="2" fill="#8B7CF6" stroke="#5B4FB0" stroke-width="2.2"/>'
    '<rect x="7" y="16" width="34" height="7" rx="2" fill="#7A6BE8" stroke="#5B4FB0" stroke-width="2.2"/>'
    '<rect x="21" y="16" width="6" height="23" fill="#F2C84B" stroke="#C9881A" stroke-width="1.6"/>'
    '<path d="M24 16 C20 8 12 11 18 16 M24 16 C28 8 36 11 30 16" fill="#F2C84B" stroke="#C9881A" stroke-width="2" stroke-linejoin="round"/>'
    '<circle cx="24" cy="15" r="2.2" fill="#F2C84B" stroke="#C9881A" stroke-width="1.2"/>'
    '</svg>';

const String _puzzle =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path d="M12 14 H21 a3 3 0 0 1 6 0 H36 V23 a3 3 0 0 1 0 6 V38 H27 a3 3 0 0 0 -6 0 H12 V29 a3 3 0 0 0 0 -6 Z" fill="#3FB59A" stroke="#15727C" stroke-width="2.2" stroke-linejoin="round"/>'
    '</svg>';

const String _wizardHat =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path d="M24 7 L36 33 H12 Z" fill="#7A4DD8" stroke="#4E2E96" stroke-width="2.2" stroke-linejoin="round"/>'
    '<ellipse cx="24" cy="34" rx="16" ry="4.5" fill="#8B5EE8" stroke="#4E2E96" stroke-width="2.2"/>'
    '<path d="M24 16 l1.4 3.4 3.6 .4 -2.7 2.5 .8 3.6 -3.1 -1.9 -3.1 1.9 .8 -3.6 -2.7 -2.5 3.6 -.4 Z" fill="#F2C84B"/>'
    '<circle cx="18" cy="26" r="1.2" fill="#FBE08A"/>'
    '<circle cx="29" cy="28" r="1.1" fill="#FBE08A"/>'
    '</svg>';

const String _fairy =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path d="M23 30 C12 30 9 18 14 14 C20 18 23 24 23 30 Z" fill="#7FD0A0" stroke="#2E8B57" stroke-width="2" stroke-linejoin="round"/>'
    '<path d="M25 30 C36 30 39 18 34 14 C28 18 25 24 25 30 Z" fill="#A6E0BC" stroke="#2E8B57" stroke-width="2" stroke-linejoin="round"/>'
    '<path d="M14 14 L23 28" fill="none" stroke="#2E8B57" stroke-width="1.2"/>'
    '<path d="M34 14 L25 28" fill="none" stroke="#2E8B57" stroke-width="1.2"/>'
    '<circle cx="24" cy="31" r="3" fill="#F4A6C8" stroke="#C03E76" stroke-width="1.6"/>'
    '<path d="M24 8 l1 2.6 2.6 1 -2.6 1 -1 2.6 -1 -2.6 -2.6 -1 2.6 -1 Z" fill="#F2C84B"/>'
    '</svg>';

const String _robot =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<line x1="24" y1="14" x2="24" y2="8" stroke="#2E6E86" stroke-width="2"/>'
    '<circle cx="24" cy="7" r="2.2" fill="#F2C84B" stroke="#2E6E86" stroke-width="1.4"/>'
    '<rect x="8" y="21" width="3.5" height="8" rx="1.5" fill="#4F95B5" stroke="#2E6E86" stroke-width="1.4"/>'
    '<rect x="36.5" y="21" width="3.5" height="8" rx="1.5" fill="#4F95B5" stroke="#2E6E86" stroke-width="1.4"/>'
    '<rect x="11" y="14" width="26" height="22" rx="6" fill="#6FB7D8" stroke="#2E6E86" stroke-width="2.2"/>'
    '<circle cx="19" cy="23" r="3" fill="#FBF6EE" stroke="#2E6E86" stroke-width="1.4"/>'
    '<circle cx="19" cy="23" r="1.3" fill="#2A2230"/>'
    '<circle cx="29" cy="23" r="3" fill="#FBF6EE" stroke="#2E6E86" stroke-width="1.4"/>'
    '<circle cx="29" cy="23" r="1.3" fill="#2A2230"/>'
    '<rect x="17" y="29" width="14" height="4" rx="2" fill="#2E6E86"/>'
    '</svg>';

/// Large home-screen action glyphs (not part of the concept vocabulary).
/// Drawn to sit directly on the tile color, no token background.
const String storybookIconSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path d="M24 16 C19 13 10 13 6 15 V39 C10 37 19 37 24 40 C29 37 38 37 42 39 V15 C38 13 29 13 24 16 Z" fill="#8B7CF6" stroke="#4E2E96" stroke-width="2.2" stroke-linejoin="round"/>'
    '<path d="M24 17 C20 14.5 13 14.5 9 16 V35 C13 33.5 20 33.5 24 36 Z" fill="#FBF6EE" stroke="#4E2E96" stroke-width="1.3" stroke-linejoin="round"/>'
    '<path d="M24 17 C28 14.5 35 14.5 39 16 V35 C35 33.5 28 33.5 24 36 Z" fill="#FBF6EE" stroke="#4E2E96" stroke-width="1.3" stroke-linejoin="round"/>'
    '<path d="M12 21 H20 M12 25 H20 M12 29 H18" stroke="#C9B79A" stroke-width="1.4" stroke-linecap="round"/>'
    '<path d="M28 21 H36 M28 25 H36 M30 29 H36" stroke="#C9B79A" stroke-width="1.4" stroke-linecap="round"/>'
    '<path d="M38 8 l1.2 3 3 1.2 -3 1.2 -1.2 3 -1.2 -3 -3 -1.2 3 -1.2 Z" fill="#F2C84B" stroke="#C9881A" stroke-width="0.8" stroke-linejoin="round"/>'
    '</svg>';

const String headphonesIconSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path d="M10 30 V24 a14 14 0 0 1 28 0 V30" fill="none" stroke="#5B4FB0" stroke-width="3.4" stroke-linecap="round"/>'
    '<rect x="6" y="27" width="9" height="14" rx="4" fill="#8B7CF6" stroke="#5B4FB0" stroke-width="2.2"/>'
    '<rect x="33" y="27" width="9" height="14" rx="4" fill="#8B7CF6" stroke="#5B4FB0" stroke-width="2.2"/>'
    '<rect x="9" y="30" width="3.5" height="8" rx="1.75" fill="#C3B8F4"/>'
    '<rect x="35.5" y="30" width="3.5" height="8" rx="1.75" fill="#C3B8F4"/>'
    '</svg>';
