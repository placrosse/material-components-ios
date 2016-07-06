/*
 Copyright 2016-present Google Inc. All Rights Reserved.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#if !defined(__has_feature) || !__has_feature(objc_arc)
#error "This file requires ARC support."
#endif

#import "MDCCollectionViewCell.h"

#import "MaterialCollectionLayoutAttributes.h"
#import "MaterialIcons+ic_check.h"
#import "MaterialIcons+ic_check_circle.h"
#import "MaterialIcons+ic_chevron_right.h"
#import "MaterialIcons+ic_info.h"
#import "MaterialIcons+ic_radio_button_unchecked.h"
#import "MaterialIcons+ic_reorder.h"
#import "MaterialRTL.h"

#define RGBCOLOR(r, g, b) \
  [UIColor colorWithRed:(r) / 255.0f green:(g) / 255.0f blue:(b) / 255.0f alpha:1]
#define HEXCOLOR(hex) RGBCOLOR((((hex) >> 16) & 0xFF), (((hex) >> 8) & 0xFF), ((hex)&0xFF))

static CGFloat kEditingControlAppearanceOffset = 16.0f;

// Default accessory insets.
static const UIEdgeInsets kAccessoryInsetDefault = {0, 16.0f, 0, 16.0f};

// Default editing icon colors.
static const uint32_t kCellGrayColor = 0x626262;
static const uint32_t kCellRedColor = 0xF44336;

// To be used as accessory view when an accessory type is set. It has no particular functionalities
// other than being a private class defined here, to check if an accessory view was set via an
// accessory type, or if the user of MDCCollectionViewCell set a custom accessory view.
@interface MDCAccessoryTypeImageView : UIImageView
@end
@implementation MDCAccessoryTypeImageView
@end

@implementation MDCCollectionViewCell {
  MDCCollectionViewLayoutAttributes *_attr;
  BOOL _usesCellSeparatorHiddenOverride;
  BOOL _usesCellSeparatorInsetOverride;
  CAShapeLayer *_separatorLayer;
  UIView *_separatorView;
  UIImageView *_backgroundImageView;
  UIImageView *_editingReorderImageView;
  UIImageView *_editingSelectorImageView;
}

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    [self commonMDCCollectionViewCellInit];
  }
  return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [super initWithCoder:aDecoder];
  if (self) {
    [self commonMDCCollectionViewCellInit];
  }
  return self;
}

- (void)commonMDCCollectionViewCellInit {
  // Separator defaults.
  _separatorView = [[UIImageView alloc] initWithFrame:CGRectZero];
  [self addSubview:_separatorView];

  // Accessory defaults.
  _accessoryType = MDCCollectionViewCellAccessoryNone;
  _accessoryInset = kAccessoryInsetDefault;
}

#pragma mark - Layout

- (void)prepareForReuse {
  [super prepareForReuse];

  // Reset properties.
  _usesCellSeparatorHiddenOverride = NO;
  _usesCellSeparatorInsetOverride = NO;
  _separatorView.hidden = YES;

  [self drawSeparatorIfNeeded];
  [self updateInterfaceForEditing];

  // Reset cells hidden during swipe deletion.
  self.hidden = NO;
}

- (void)layoutSubviews {
  [super layoutSubviews];

  // Layout the accessory view and the content view.
  [self layoutForegroundSubviews];

  // Animate editing controls.
  [UIView
      animateWithDuration:0.3
               animations:^{
                 CGFloat txReorderTransform;
                 CGFloat txSelectorTransform;
                 switch (self.mdc_effectiveUserInterfaceLayoutDirection) {
                   case UIUserInterfaceLayoutDirectionLeftToRight:
                     txReorderTransform = kEditingControlAppearanceOffset;
                     txSelectorTransform = -kEditingControlAppearanceOffset;
                     break;
                   case UIUserInterfaceLayoutDirectionRightToLeft:
                     txReorderTransform = -kEditingControlAppearanceOffset;
                     txSelectorTransform = kEditingControlAppearanceOffset;
                     break;
                 }
                 _editingReorderImageView.alpha = _attr.shouldShowReorderStateMask ? 1.0f : 0.0f;
                 _editingReorderImageView.transform =
                     _attr.shouldShowReorderStateMask
                         ? CGAffineTransformMakeTranslation(txReorderTransform, 0)
                         : CGAffineTransformIdentity;

                 _editingSelectorImageView.alpha = _attr.shouldShowSelectorStateMask ? 1.0f : 0.0f;
                 _editingSelectorImageView.transform =
                     _attr.shouldShowSelectorStateMask
                         ? CGAffineTransformMakeTranslation(txSelectorTransform, 0)
                         : CGAffineTransformIdentity;
               }];
}

- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes {
  [super applyLayoutAttributes:layoutAttributes];
  if ([layoutAttributes isKindOfClass:[MDCCollectionViewLayoutAttributes class]]) {
    _attr = (MDCCollectionViewLayoutAttributes *)layoutAttributes;

    if (_attr.representedElementCategory == UICollectionElementCategoryCell) {
      [self setEditing:_attr.editing];
    }

    // Create image view to hold cell background image with shadowing.
    if (!_backgroundImageView) {
      _backgroundImageView = [[UIImageView alloc] initWithFrame:self.bounds];
      self.backgroundView = _backgroundImageView;
    }
    _backgroundImageView.image = _attr.backgroundImage;

    // Draw separator if needed.
    [self drawSeparatorIfNeeded];

    // Layout the accessory view and the content view.
    [self layoutForegroundSubviews];

    // Animate cell on appearance settings.
    [self updateAppearanceAnimation];
  }
}

- (void)layoutForegroundSubviews {
  // First lay out the accessory view.
  _accessoryView.frame = [self accessoryFrame];
  // Then lay out the content view, inset by the accessory view's width.
  self.contentView.frame = [self contentViewFrame];
}

#pragma mark - Accessory Views

- (void)setAccessoryType:(MDCCollectionViewCellAccessoryType)accessoryType {
  _accessoryType = accessoryType;

  UIImageView *accessoryImageView = nil;
  if (!_accessoryView && accessoryType != MDCCollectionViewCellAccessoryNone) {
    // Add accessory view.
    accessoryImageView = [[MDCAccessoryTypeImageView alloc] initWithFrame:CGRectZero];
    _accessoryView = accessoryImageView;
    _accessoryView.userInteractionEnabled = NO;
    [self addSubview:_accessoryView];
  }

  switch (_accessoryType) {
    case MDCCollectionViewCellAccessoryDisclosureIndicator: {
      UIImage *image = [UIImage imageWithContentsOfFile:[MDCIcons pathFor_ic_chevron_right]];
      if (self.mdc_effectiveUserInterfaceLayoutDirection ==
          UIUserInterfaceLayoutDirectionRightToLeft) {
        image = [image mdc_imageFlippedForRightToLeftLayoutDirection];
      }
      accessoryImageView.image = image;
      break;
    }
    case MDCCollectionViewCellAccessoryCheckmark: {
      UIImage *image = [UIImage imageWithContentsOfFile:[MDCIcons pathFor_ic_check]];
      accessoryImageView.image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
      break;
    }
    case MDCCollectionViewCellAccessoryDetailButton: {
      UIImage *image = [UIImage imageWithContentsOfFile:[MDCIcons pathFor_ic_info]];
      accessoryImageView.image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
      break;
    }
    case MDCCollectionViewCellAccessoryNone: {
      [_accessoryView removeFromSuperview];
      _accessoryView = nil;
      break;
    }
  }
  [_accessoryView sizeToFit];
}

- (void)setAccessoryView:(UIView *)accessoryView {
  if (!_accessoryView) {
    [self addSubview:accessoryView];
  }
  _accessoryView = accessoryView;
}

- (CGRect)accessoryFrame {
  CGSize size = _accessoryView.frame.size;
  CGFloat originX = CGRectGetWidth(self.bounds) - size.width - _accessoryInset.right;
  CGFloat originY = (CGRectGetHeight(self.bounds) - size.height) / 2;
  CGRect frame = CGRectMake(originX, originY, size.width, size.height);
  return MDCRectFlippedForRTL(frame, CGRectGetWidth(self.bounds),
                              self.mdc_effectiveUserInterfaceLayoutDirection);
}

#pragma mark - Separator

- (void)setShouldHideSeparator:(BOOL)shouldHideSeparator {
  _usesCellSeparatorHiddenOverride = YES;
  _shouldHideSeparator = shouldHideSeparator;
  [self drawSeparatorIfNeeded];
}

- (void)setSeparatorInset:(UIEdgeInsets)separatorInset {
  _usesCellSeparatorInsetOverride = YES;
  _separatorInset = separatorInset;
  [self drawSeparatorIfNeeded];
}

- (void)drawSeparatorIfNeeded {
  // Determine separator spec from attributes and cell overrides. Don't draw separator for bottom
  // cell or in grid layout cells. Separators are added here as cell subviews instead of decoration
  // views registered with the layout to overcome inability to animate decoration views in
  // coordination with cell animations.
  BOOL isHidden =
      _usesCellSeparatorHiddenOverride ? _shouldHideSeparator : _attr.shouldHideSeparators;
  UIEdgeInsets separatorInset =
      _usesCellSeparatorInsetOverride ? _separatorInset : _attr.separatorInset;
  BOOL isBottom = _attr.sectionOrdinalPosition & MDCCollectionViewOrdinalPositionVerticalBottom;
  BOOL isGrid = _attr.isGridLayout;

  BOOL hideSeparator = isBottom || isHidden || isGrid;
  if (hideSeparator != _separatorView.hidden) {
    _separatorView.hidden = hideSeparator;
  }

  if (!hideSeparator) {
    UIEdgeInsets insets = _attr.backgroundImageViewInsets;
    CGFloat separatorOriginX;
    switch (self.mdc_effectiveUserInterfaceLayoutDirection) {
      case UIUserInterfaceLayoutDirectionLeftToRight:
        separatorOriginX = insets.left;
        break;
      case UIUserInterfaceLayoutDirectionRightToLeft:
        separatorOriginX = insets.right;
        break;
    }
    CGRect separatorFrame = CGRectMake(
        separatorOriginX, CGRectGetHeight(self.bounds) - _attr.separatorLineHeight,
        CGRectGetWidth(self.bounds) - insets.left - insets.right, _attr.separatorLineHeight);
    _separatorView.frame = UIEdgeInsetsInsetRect(separatorFrame, separatorInset);
    _separatorView.backgroundColor = _attr.separatorColor;
  }
}

#pragma mark - Editing

- (void)setEditing:(BOOL)editing {
  [self setEditing:editing animated:NO];
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
  if (_editing == editing) {
    return;
  }
  _editing = editing;
  [self updateInterfaceForEditing];
}

- (void)updateInterfaceForEditing {
  self.contentView.userInteractionEnabled = [self shouldEnableCellInteractions];

  if (_editing) {
    // Disable implicit animations when setting initial positioning of these subviews.
    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    // Create reorder editing controls.
    if (_attr.shouldShowReorderStateMask && !_editingReorderImageView) {
      UIImage *reorderImage = [UIImage imageWithContentsOfFile:[MDCIcons pathFor_ic_reorder]];
      reorderImage = [reorderImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
      _editingReorderImageView = [[UIImageView alloc] initWithImage:reorderImage];
      _editingReorderImageView.tintColor = HEXCOLOR(kCellGrayColor);
      _editingReorderImageView.alpha = 0.0f;
      CGRect frame = (CGRect){{0, (CGRectGetHeight(self.bounds) - reorderImage.size.height) / 2},
                              reorderImage.size};
      _editingReorderImageView.autoresizingMask =
          MDCAutoresizingFlexibleTrailingMargin(self.mdc_effectiveUserInterfaceLayoutDirection);
      _editingReorderImageView.frame = MDCRectFlippedForRTL(
          frame, CGRectGetWidth(self.bounds), self.mdc_effectiveUserInterfaceLayoutDirection);
      [self addSubview:_editingReorderImageView];
    }

    // Create selector editing controls.
    if (_attr.shouldShowSelectorStateMask && !_editingSelectorImageView) {
      UIImage *selectorImage =
          [UIImage imageWithContentsOfFile:[MDCIcons pathFor_ic_radio_button_unchecked]];
      selectorImage = [selectorImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
      _editingSelectorImageView = [[UIImageView alloc] initWithImage:selectorImage];
      _editingSelectorImageView.tintColor = HEXCOLOR(kCellGrayColor);
      _editingSelectorImageView.alpha = 0.0f;
      CGFloat originX = CGRectGetWidth(self.bounds) - selectorImage.size.width;
      CGFloat originY = (CGRectGetHeight(self.bounds) - selectorImage.size.height) / 2;
      CGRect frame = (CGRect){{originX, originY}, selectorImage.size};
      _editingSelectorImageView.autoresizingMask =
          MDCAutoresizingFlexibleLeadingMargin(self.mdc_effectiveUserInterfaceLayoutDirection);
      _editingSelectorImageView.frame = MDCRectFlippedForRTL(
          frame, CGRectGetWidth(self.bounds), self.mdc_effectiveUserInterfaceLayoutDirection);
      [self addSubview:_editingSelectorImageView];
    }
    [CATransaction commit];
  }

  // Update accessory view.
  _accessoryView.alpha = _attr.shouldShowSelectorStateMask ? 0.0f : 1.0f;
  _accessoryInset.right = _attr.shouldShowSelectorStateMask
                              ? kAccessoryInsetDefault.right + kEditingControlAppearanceOffset
                              : kAccessoryInsetDefault.right;
}

#pragma mark - Selecting

- (void)setSelected:(BOOL)selected {
  [super setSelected:selected];
  if (selected) {
    _editingSelectorImageView.image =
        [UIImage imageWithContentsOfFile:[MDCIcons pathFor_ic_check_circle]];
    _editingSelectorImageView.tintColor = HEXCOLOR(kCellRedColor);
  } else {
    _editingSelectorImageView.image =
        [UIImage imageWithContentsOfFile:[MDCIcons pathFor_ic_radio_button_unchecked]];
    _editingSelectorImageView.tintColor = HEXCOLOR(kCellGrayColor);
  }
  _editingSelectorImageView.image =
      [_editingSelectorImageView.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
}

#pragma mark - Cell Appearance Animation

- (void)updateAppearanceAnimation {
  if (_attr.animateCellsOnAppearanceDelay > 0) {
    // Intially hide content view and separator.
    self.contentView.alpha = 0;
    _separatorView.alpha = 0;

    // Animate fade-in after delay.
    if (!_attr.willAnimateCellsOnAppearance) {
      [UIView animateWithDuration:_attr.animateCellsOnAppearanceDuration
                            delay:_attr.animateCellsOnAppearanceDelay
                          options:UIViewAnimationOptionCurveEaseOut
                       animations:^{
                         self.contentView.alpha = 1;
                         _separatorView.alpha = 1;
                       }
                       completion:nil];
    }
  }
}

#pragma mark - RTL

- (void)mdc_setSemanticContentAttribute:(UISemanticContentAttribute)mdc_semanticContentAttribute {
  [super mdc_setSemanticContentAttribute:mdc_semanticContentAttribute];
  // Reload the accessory type image if there is one.
  if ([_accessoryView isKindOfClass:[MDCAccessoryTypeImageView class]]) {
    self.accessoryType = self.accessoryType;
  }
}

#pragma mark - Private

- (CGRect)contentViewFrame {
  CGFloat leadingPadding =
      _attr.shouldShowReorderStateMask
          ? CGRectGetWidth(_editingReorderImageView.bounds) + kEditingControlAppearanceOffset
          : 0.f;

  CGFloat accessoryViewPadding =
      _accessoryView ? CGRectGetWidth(self.bounds) - CGRectGetMinX(_accessoryView.frame) : 0;
  CGFloat trailingPadding =
      _attr.shouldShowSelectorStateMask
          ? CGRectGetWidth(_editingSelectorImageView.bounds) + kEditingControlAppearanceOffset
          : accessoryViewPadding;
  UIEdgeInsets insets = MDCInsetsMakeWithLayoutDirection(
      0, leadingPadding, 0, trailingPadding, self.mdc_effectiveUserInterfaceLayoutDirection);
  return UIEdgeInsetsInsetRect(self.bounds, insets);
}

- (BOOL)shouldEnableCellInteractions {
  return !_editing || _allowsCellInteractionsWhileEditing;
}

@end
