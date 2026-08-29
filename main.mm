#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#include <algorithm>
#include <cstdlib>
#include <ctime>
#include <deque>
#include <string>

enum GameMode { MODE_FRIEND, MODE_BOT };
enum ScreenState { SCREEN_MENU, SCREEN_MODE, SCREEN_NAMES, SCREEN_GAME, SCREEN_OVER };

static const int WIN_LINES[8][3] = {
	{0, 1, 2}, {3, 4, 5}, {6, 7, 8},
	{0, 3, 6}, {1, 4, 7}, {2, 5, 8},
	{0, 4, 8}, {2, 4, 6}
};

static const int MAX_HISTORY = 10;

struct GameRecord
{
	int number;
	GameMode mode;
	char result;
	std::string winnerName;
};

class ScoreHistory
{
public:
	ScoreHistory() : total_(0), xWins_(0), oWins_(0), draws_(0) {}

	void add(GameMode mode, char winner, bool draw, const std::string& winnerName)
	{
		GameRecord rec;
		rec.number = ++total_;
		rec.mode = mode;
		rec.result = draw ? 'D' : winner;
		rec.winnerName = winnerName;
		records_.push_back(rec);
		if ((int)records_.size() > MAX_HISTORY)
			records_.pop_front();

		if (draw) ++draws_;
		else if (winner == 'X') ++xWins_;
		else if (winner == 'O') ++oWins_;
	}

	int total() const { return total_; }
	int xWins() const { return xWins_; }
	int oWins() const { return oWins_; }
	int draws() const { return draws_; }
	const std::deque<GameRecord>& records() const { return records_; }

private:
	std::deque<GameRecord> records_;
	int total_;
	int xWins_;
	int oWins_;
	int draws_;
};

static NSColor* colorFromRGB(float r, float g, float b)
{
	return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:1.0f];
}

static NSColor* colorFromRGBA(float r, float g, float b, float a)
{
	return [NSColor colorWithCalibratedRed:r green:g blue:b alpha:a];
}

static NSColor* bgCell()        { return colorFromRGB(0.07f, 0.09f, 0.15f); }
static NSColor* bgCellHover()   { return colorFromRGB(0.10f, 0.12f, 0.20f); }
static NSColor* textMuted()     { return colorFromRGB(0.52f, 0.56f, 0.64f); }
static NSColor* textDim()       { return colorFromRGB(0.32f, 0.36f, 0.44f); }
static NSColor* btnFill()       { return colorFromRGB(0.09f, 0.11f, 0.17f); }
static NSColor* btnHover()      { return colorFromRGB(0.13f, 0.15f, 0.23f); }
static NSColor* borderSubtle()  { return colorFromRGB(0.18f, 0.21f, 0.28f); }
static NSColor* strokeSoft()    { return colorFromRGBA(0.24f, 0.28f, 0.40f, 0.55f); }
static NSColor* strokeHover()   { return colorFromRGBA(0.38f, 0.44f, 0.58f, 0.85f); }
static NSColor* brightX()       { return colorFromRGB(1.00f, 0.38f, 0.48f); }
static NSColor* brightO()       { return colorFromRGB(0.25f, 0.82f, 1.00f); }

static CGFloat centerX(CGFloat viewW, CGFloat w)
{
	return (viewW - w) / 2.0;
}

@interface BackgroundView : NSView
@end

@implementation BackgroundView

- (BOOL)isOpaque { return YES; }

- (void)drawRect:(NSRect)dirtyRect
{
	(void)dirtyRect;
	NSRect b = self.bounds;

	NSGradient* base = [[NSGradient alloc] initWithColors:@[
		colorFromRGB(0.03f, 0.04f, 0.08f),
		colorFromRGB(0.05f, 0.07f, 0.14f),
		colorFromRGB(0.04f, 0.06f, 0.12f)
	]];
	[base drawInRect:b angle:90.0];

	NSGraphicsContext* ctx = [NSGraphicsContext currentContext];
	[ctx saveGraphicsState];

	NSPoint center = NSMakePoint(NSMidX(b), NSMidY(b) + b.size.height * 0.08);
	NSGradient* glow = [[NSGradient alloc] initWithStartingColor:colorFromRGBA(0.10f, 0.18f, 0.38f, 0.22f)
		endingColor:colorFromRGBA(0.04f, 0.06f, 0.12f, 0.0f)];
	[glow drawFromCenter:center radius:0 toCenter:center radius:b.size.width * 0.55 options:0];

	NSGradient* glow2 = [[NSGradient alloc] initWithStartingColor:colorFromRGBA(0.18f, 0.08f, 0.28f, 0.08f)
		endingColor:colorFromRGBA(0.04f, 0.06f, 0.12f, 0.0f)];
	[glow2 drawFromCenter:NSMakePoint(b.size.width * 0.18, b.size.height * 0.72) radius:0
		toCenter:NSMakePoint(b.size.width * 0.18, b.size.height * 0.72) radius:b.size.width * 0.35 options:0];

	[glow2 drawFromCenter:NSMakePoint(b.size.width * 0.82, b.size.height * 0.28) radius:0
		toCenter:NSMakePoint(b.size.width * 0.82, b.size.height * 0.28) radius:b.size.width * 0.30 options:0];

	[ctx restoreGraphicsState];

	[colorFromRGBA(1.0f, 1.0f, 1.0f, 0.04f) setFill];
	for (int i = 0; i < 40; ++i)
	{
		float fx = (float)(i * 73 % 100) / 100.0f;
		float fy = (float)(i * 41 % 100) / 100.0f;
		NSRect dot = NSMakeRect(b.size.width * fx, b.size.height * fy, 1.2, 1.2);
		NSRectFill(dot);
	}
}

@end

@interface XOTitleView : NSView
@property (nonatomic, assign) CGFloat fontSize;
@end

@implementation XOTitleView

- (void)drawRect:(NSRect)dirtyRect
{
	(void)dirtyRect;
	NSFont* font = [NSFont boldSystemFontOfSize:self.fontSize > 0 ? self.fontSize : 72];

	NSDictionary* xAttr = @{ NSFontAttributeName: font, NSForegroundColorAttributeName: brightX() };
	NSDictionary* sepAttr = @{ NSFontAttributeName: font, NSForegroundColorAttributeName: textDim() };
	NSDictionary* oAttr = @{ NSFontAttributeName: font, NSForegroundColorAttributeName: brightO() };

	NSString* x = @"X";
	NSString* sep = @"  /  ";
	NSString* o = @"O";

	NSSize xSize = [x sizeWithAttributes:xAttr];
	NSSize sepSize = [sep sizeWithAttributes:sepAttr];
	NSSize oSize = [o sizeWithAttributes:oAttr];
	CGFloat totalW = xSize.width + sepSize.width + oSize.width;

	CGFloat startX = (self.bounds.size.width - totalW) / 2.0;
	CGFloat baselineY = (self.bounds.size.height - font.capHeight) / 2.0 - 4.0;

	[x drawAtPoint:NSMakePoint(startX, baselineY) withAttributes:xAttr];
	startX += xSize.width;
	[sep drawAtPoint:NSMakePoint(startX, baselineY) withAttributes:sepAttr];
	startX += sepSize.width;
	[o drawAtPoint:NSMakePoint(startX, baselineY) withAttributes:oAttr];
}

@end

@interface ScorePanelView : NSView
@end

@implementation ScorePanelView

- (void)drawRect:(NSRect)dirtyRect
{
	(void)dirtyRect;
	NSRect box = NSInsetRect(self.bounds, 0, 0);
	NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:box xRadius:14 yRadius:14];
	[colorFromRGBA(0.08f, 0.10f, 0.18f, 0.72f) setFill];
	[path fill];
	[colorFromRGBA(0.22f, 0.26f, 0.38f, 0.35f) setStroke];
	path.lineWidth = 1.0;
	[path stroke];
}

@end

static void drawMark(char mark, NSRect bounds, NSColor* color, CGFloat alpha, CGFloat scale)
{
	if (mark != 'X' && mark != 'O')
		return;

	NSGraphicsContext* ctx = [NSGraphicsContext currentContext];
	[ctx saveGraphicsState];

	NSAffineTransform* xf = [NSAffineTransform transform];
	[xf translateXBy:NSMidX(bounds) yBy:NSMidY(bounds)];
	[xf scaleBy:scale];
	[xf translateXBy:-NSMidX(bounds) yBy:-NSMidY(bounds)];
	[xf concat];

	NSColor* drawColor = [color colorWithAlphaComponent:alpha];
	NSDictionary* attrs = @{
		NSFontAttributeName: [NSFont boldSystemFontOfSize:72],
		NSForegroundColorAttributeName: drawColor
	};

	NSPoint pt = (mark == 'X')
		? NSMakePoint(bounds.size.width * 0.28, bounds.size.height * 0.18)
		: NSMakePoint(bounds.size.width * 0.22, bounds.size.height * 0.18);

	[[NSString stringWithFormat:@"%c", mark] drawAtPoint:pt withAttributes:attrs];
	[ctx restoreGraphicsState];
}

class TicTacToeEngine
{
public:
	TicTacToeEngine() : current_('X'), over_(false), winner_(' '), draw_(false), hasWinLine_(false)
	{
		reset();
	}

	void reset()
	{
		for (int i = 0; i < 9; ++i)
			board_[i] = ' ';
		current_ = 'X';
		over_ = false;
		winner_ = ' ';
		draw_ = false;
		hasWinLine_ = false;
	}

	char current() const { return current_; }
	bool over() const { return over_; }
	char winner() const { return winner_; }
	bool draw() const { return draw_; }
	bool hasWinLine() const { return hasWinLine_; }

	char at(int i) const { return board_[i]; }

	bool isWinningCell(int i) const
	{
		if (!hasWinLine_) return false;
		return i == winLine_[0] || i == winLine_[1] || i == winLine_[2];
	}

	bool play(int pos)
	{
		if (over_ || pos < 0 || pos > 8 || board_[pos] != ' ')
			return false;

		board_[pos] = current_;

		if (checkWin(current_))
		{
			over_ = true;
			winner_ = current_;
			return true;
		}
		if (isFull())
		{
			over_ = true;
			draw_ = true;
			return true;
		}
		current_ = (current_ == 'X') ? 'O' : 'X';
		return true;
	}

	int botMove()
	{
		int best = -1;
		int bestScore = -1000;
		for (int i = 0; i < 9; ++i)
		{
			if (board_[i] != ' ')
				continue;
			board_[i] = 'O';
			int score = minimax(false);
			board_[i] = ' ';
			if (score > bestScore)
			{
				bestScore = score;
				best = i;
			}
		}
		return best;
	}

private:
	char board_[9];
	char current_;
	bool over_;
	char winner_;
	bool draw_;
	bool hasWinLine_;
	int winLine_[3];

	bool lineWin(char p) const
	{
		for (int i = 0; i < 8; ++i)
		{
			if (board_[WIN_LINES[i][0]] == p &&
				board_[WIN_LINES[i][1]] == p &&
				board_[WIN_LINES[i][2]] == p)
				return true;
		}
		return false;
	}

	bool checkWin(char p)
	{
		for (int i = 0; i < 8; ++i)
		{
			if (board_[WIN_LINES[i][0]] == p &&
				board_[WIN_LINES[i][1]] == p &&
				board_[WIN_LINES[i][2]] == p)
			{
				hasWinLine_ = true;
				winLine_[0] = WIN_LINES[i][0];
				winLine_[1] = WIN_LINES[i][1];
				winLine_[2] = WIN_LINES[i][2];
				return true;
			}
		}
		return false;
	}

	bool isFull() const
	{
		for (int i = 0; i < 9; ++i)
			if (board_[i] == ' ')
				return false;
		return true;
	}

	int minimax(bool maximizing)
	{
		if (lineWin('O')) return 10;
		if (lineWin('X')) return -10;
		if (isFull()) return 0;

		if (maximizing)
		{
			int best = -1000;
			for (int i = 0; i < 9; ++i)
			{
				if (board_[i] != ' ')
					continue;
				board_[i] = 'O';
				best = std::max(best, minimax(false));
				board_[i] = ' ';
			}
			return best;
		}
		int best = 1000;
		for (int i = 0; i < 9; ++i)
		{
			if (board_[i] != ' ')
				continue;
			board_[i] = 'X';
			best = std::min(best, minimax(true));
			board_[i] = ' ';
		}
		return best;
	}
};

@class CellButton;
@class NameInputView;

@interface GameViewController : NSViewController
@property (nonatomic, assign) ScreenState screen;
@property (nonatomic, assign) GameMode mode;
@property (nonatomic, assign) TicTacToeEngine* engine;
@property (nonatomic, assign) ScoreHistory* history;
@property (nonatomic, strong) NSTextField* statusLabel;
@property (nonatomic, strong) NSTextField* scorePanel;
@property (nonatomic, strong) NSTextField* scoreSummaryLabel;
@property (nonatomic, strong) NSTextField* resultLabel;
@property (nonatomic, strong) NSView* overOverlay;
@property (nonatomic, strong) NSMutableArray* cellButtons;
@property (nonatomic, strong) NSTimer* finishTimer;
@property (nonatomic, assign) BOOL inputLocked;
@property (nonatomic, strong) NSString* nameX;
@property (nonatomic, strong) NSString* nameO;
@property (nonatomic, strong) NameInputView* nameInput1;
@property (nonatomic, strong) NameInputView* nameInput2;
- (char)previewMarkForCell:(CellButton*)cell;
@end

@interface BrightButton : NSButton
@property (nonatomic, strong) NSColor* fillColor;
@property (nonatomic, strong) NSColor* hoverColor;
@property (nonatomic, assign) BOOL hovering;
@end

@implementation BrightButton

- (instancetype)initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	if (self)
	{
		self.bordered = NO;
		self.wantsLayer = YES;
		self.hovering = NO;
	}
	return self;
}

- (void)updateTrackingAreas
{
	[super updateTrackingAreas];
	for (NSTrackingArea* area in self.trackingAreas)
		[self removeTrackingArea:area];

	NSTrackingAreaOptions opts = NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect;
	NSTrackingArea* track = [[NSTrackingArea alloc] initWithRect:self.bounds
		options:opts owner:self userInfo:nil];
	[self addTrackingArea:track];
}

- (void)mouseEntered:(NSEvent*)event
{
	(void)event;
	self.hovering = YES;
	[self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent*)event
{
	(void)event;
	self.hovering = NO;
	[self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
	(void)dirtyRect;
	NSRect box = NSInsetRect(self.bounds, 1.5, 1.5);
	NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:box xRadius:18 yRadius:18];

	NSColor* fill = self.hovering ? self.hoverColor : self.fillColor;
	[fill setFill];
	[path fill];

	NSColor* stroke = self.hovering ? strokeHover() : strokeSoft();
	[stroke setStroke];
	path.lineWidth = 1.25;
	[path stroke];

	NSDictionary* attrs = @{
		NSFontAttributeName: self.font ?: [NSFont systemFontOfSize:20 weight:NSFontWeightMedium],
		NSForegroundColorAttributeName: textMuted()
	};
	NSString* title = self.title ?: @"";
	NSSize textSize = [title sizeWithAttributes:attrs];
	NSPoint pt = NSMakePoint(
		(self.bounds.size.width - textSize.width) / 2.0,
		(self.bounds.size.height - textSize.height) / 2.0
	);
	[title drawAtPoint:pt withAttributes:attrs];
}

@end

@interface NameInputView : NSView
@property (nonatomic, strong) NSTextField* field;
@property (nonatomic, assign) BOOL focused;
@end

@implementation NameInputView

- (instancetype)initWithFrame:(NSRect)frame placeholder:(NSString*)placeholder
{
	self = [super initWithFrame:frame];
	if (self)
	{
		self.wantsLayer = NO;
		self.focused = NO;

		CGFloat pad = 14.0;
		self.field = [[NSTextField alloc] initWithFrame:NSMakeRect(pad, (frame.size.height - 28.0) / 2.0,
			frame.size.width - pad * 2.0, 28.0)];
		self.field.bezeled = NO;
		self.field.bordered = NO;
		self.field.editable = YES;
		self.field.selectable = YES;
		self.field.drawsBackground = NO;
		self.field.backgroundColor = [NSColor clearColor];
		self.field.textColor = textMuted();
		self.field.font = [NSFont systemFontOfSize:18 weight:NSFontWeightRegular];
		self.field.alignment = NSTextAlignmentCenter;
		self.field.placeholderString = placeholder;
		self.field.stringValue = @"";
		self.field.focusRingType = NSFocusRingTypeNone;

		NSColor* placeholderColor = textDim();
		self.field.placeholderAttributedString = [[NSAttributedString alloc]
			initWithString:placeholder ?: @""
			attributes:@{
				NSFontAttributeName: self.field.font,
				NSForegroundColorAttributeName: placeholderColor
			}];

		[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(beginEdit:)
			name:NSTextDidBeginEditingNotification
			object:self.field];
		[[NSNotificationCenter defaultCenter] addObserver:self
			selector:@selector(endEdit:)
			name:NSTextDidEndEditingNotification
			object:self.field];

		[self addSubview:self.field];
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)beginEdit:(NSNotification*)note
{
	(void)note;
	self.focused = YES;
	[self setNeedsDisplay:YES];
}

- (void)endEdit:(NSNotification*)note
{
	(void)note;
	self.focused = NO;
	[self setNeedsDisplay:YES];
}

- (BOOL)acceptsFirstResponder { return YES; }

- (BOOL)becomeFirstResponder
{
	return [self.window makeFirstResponder:self.field];
}

- (void)drawRect:(NSRect)dirtyRect
{
	(void)dirtyRect;
	NSRect box = NSInsetRect(self.bounds, 1.0, 1.0);
	NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:box xRadius:16 yRadius:16];

	[colorFromRGB(0.07f, 0.09f, 0.15f) setFill];
	[path fill];

	NSColor* stroke = self.focused ? strokeHover() : strokeSoft();
	[stroke setStroke];
	path.lineWidth = self.focused ? 1.5 : 1.25;
	[path stroke];
}

@end

@interface CellButton : NSButton
@property (nonatomic, assign) char mark;
@property (nonatomic, assign) char previewMark;
@property (nonatomic, assign) BOOL hoverGlow;
@property (nonatomic, assign) BOOL isWinningCell;
@property (nonatomic, assign) CGFloat markScale;
@property (nonatomic, assign) CGFloat markAlpha;
@property (nonatomic, assign) CGFloat winPulse;
@property (nonatomic, assign) BOOL interactionEnabled;
@property (nonatomic, assign) GameViewController* owner;
@end

@implementation CellButton

- (instancetype)initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	if (self)
	{
		self.bordered = NO;
		self.wantsLayer = YES;
		self.mark = ' ';
		self.previewMark = ' ';
		self.hoverGlow = NO;
		self.isWinningCell = NO;
		self.markScale = 1.0;
		self.markAlpha = 1.0;
		self.winPulse = 0.0;
		self.interactionEnabled = YES;
	}
	return self;
}

- (void)updateTrackingAreas
{
	[super updateTrackingAreas];
	for (NSTrackingArea* area in self.trackingAreas)
		[self removeTrackingArea:area];

	NSTrackingAreaOptions opts = NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways | NSTrackingInVisibleRect;
	NSTrackingArea* track = [[NSTrackingArea alloc] initWithRect:self.bounds
		options:opts owner:self userInfo:nil];
	[self addTrackingArea:track];
}

- (void)clearPreview
{
	self.previewMark = ' ';
	self.hoverGlow = NO;
	[self setNeedsDisplay:YES];
}

- (void)mouseEntered:(NSEvent*)event
{
	(void)event;
	if (!self.interactionEnabled || self.mark != ' ')
		return;
	if (!self.owner)
		return;

	char preview = [self.owner previewMarkForCell:self];
	if (preview == ' ')
		return;

	self.previewMark = preview;
	self.hoverGlow = YES;
	[self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent*)event
{
	(void)event;
	[self clearPreview];
}

- (void)animatePlaceMark:(char)newMark completion:(void (^)(void))completion
{
	self.previewMark = ' ';
	self.hoverGlow = NO;
	self.mark = newMark;
	self.markScale = 0.35;
	self.markAlpha = 0.0;

	__block int step = 0;
	const int totalSteps = 14;
	NSTimer* timer = [NSTimer scheduledTimerWithTimeInterval:0.016 repeats:YES block:^(NSTimer* t) {
		step++;
		float p = (float)step / (float)totalSteps;
		if (p > 1.0f) p = 1.0f;
		float eased = 1.0f - (1.0f - p) * (1.0f - p);
		self.markScale = 0.35 + 0.65 * eased;
		self.markAlpha = eased;
		[self setNeedsDisplay:YES];
		if (step >= totalSteps)
		{
			[t invalidate];
			self.markScale = 1.0;
			self.markAlpha = 1.0;
			[self setNeedsDisplay:YES];
			if (completion)
				completion();
		}
	}];
	(void)timer;
}

- (void)drawRect:(NSRect)dirtyRect
{
	(void)dirtyRect;

	NSRect cellRect = NSInsetRect(self.bounds, 4, 4);
	NSColor* bg = self.hoverGlow ? bgCellHover() : bgCell();
	if (self.isWinningCell)
	{
		float pulse = 0.5f + 0.5f * sinf((float)self.winPulse * 6.0f);
		bg = colorFromRGBA(0.12f + 0.08f * pulse, 0.14f + 0.06f * pulse, 0.24f + 0.10f * pulse, 1.0f);
	}

	[bg setFill];
	NSBezierPath* path = [NSBezierPath bezierPathWithRoundedRect:cellRect xRadius:12 yRadius:12];
	[path fill];

	NSColor* border = self.isWinningCell ? colorFromRGBA(1.0f, 1.0f, 1.0f, 0.25f + 0.25f * sinf((float)self.winPulse * 6.0f)) : borderSubtle();
	[border setStroke];
	path.lineWidth = self.isWinningCell ? 2.5 : 1.5;
	[path stroke];

	if (self.mark == ' ' && self.previewMark != ' ')
	{
		NSColor* previewColor = (self.previewMark == 'X') ? brightX() : brightO();
		drawMark(self.previewMark, self.bounds, previewColor, 0.28, 0.92);
	}

	if (self.mark == 'X')
		drawMark('X', self.bounds, brightX(), self.markAlpha, self.markScale);
	else if (self.mark == 'O')
		drawMark('O', self.bounds, brightO(), self.markAlpha, self.markScale);
}

@end

@implementation GameViewController

- (void)loadView
{
	self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 720, 760)];
	self.view.wantsLayer = YES;
	self.engine = new TicTacToeEngine();
	self.history = new ScoreHistory();
	self.cellButtons = [NSMutableArray array];
	self.screen = SCREEN_MENU;
	self.inputLocked = NO;
	self.nameX = @"Player 1";
	self.nameO = @"Player 2";
	[self buildUI];
}

- (void)dealloc
{
	[self.finishTimer invalidate];
	delete self.engine;
	delete self.history;
}

- (char)previewMarkForCell:(CellButton*)cell
{
	(void)cell;
	if (self.inputLocked || self.engine->over())
		return ' ';
	if (self.mode == MODE_BOT && self.engine->current() == 'O')
		return ' ';
	return self.engine->current();
}

- (void)buildUI
{
	[self.finishTimer invalidate];
	self.finishTimer = nil;
	self.inputLocked = NO;

	for (NSView* sub in [self.view.subviews copy])
		[sub removeFromSuperview];
	[self.cellButtons removeAllObjects];
	self.overOverlay = nil;
	self.resultLabel = nil;
	self.scorePanel = nil;
	self.scoreSummaryLabel = nil;
	self.nameInput1 = nil;
	self.nameInput2 = nil;

	BackgroundView* bg = [[BackgroundView alloc] initWithFrame:self.view.bounds];
	bg.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
	[self.view addSubview:bg];

	if (self.screen == SCREEN_MENU)
		[self buildMenuScreen];
	else if (self.screen == SCREEN_MODE)
		[self buildModeScreen];
	else if (self.screen == SCREEN_NAMES)
		[self buildNamesScreen];
	else if (self.screen == SCREEN_GAME)
		[self buildGameScreen];
	else
		[self buildOverScreen];
}

- (NSTextField*)makeTitle:(NSString*)text frame:(NSRect)frame size:(CGFloat)size color:(NSColor*)color
{
	NSTextField* label = [[NSTextField alloc] initWithFrame:frame];
	label.stringValue = text;
	label.bezeled = NO;
	label.editable = NO;
	label.drawsBackground = NO;
	label.alignment = NSTextAlignmentCenter;
	label.font = [NSFont boldSystemFontOfSize:size];
	label.textColor = color;
	return label;
}

- (BrightButton*)makeButton:(NSString*)title frame:(NSRect)frame action:(SEL)action
{
	BrightButton* btn = [[BrightButton alloc] initWithFrame:frame];
	btn.title = title;
	btn.font = [NSFont systemFontOfSize:18 weight:NSFontWeightMedium];
	btn.fillColor = btnFill();
	btn.hoverColor = btnHover();
	btn.target = self;
	btn.action = action;
	return btn;
}

- (CGFloat)viewW { return self.view.bounds.size.width; }
- (CGFloat)viewH { return self.view.bounds.size.height; }

- (XOTitleView*)makeXOTitle:(CGFloat)y height:(CGFloat)height size:(CGFloat)size
{
	XOTitleView* title = [[XOTitleView alloc] initWithFrame:NSMakeRect(0, y, self.viewW, height)];
	title.fontSize = size;
	return title;
}

- (NameInputView*)makeNameInput:(NSRect)frame placeholder:(NSString*)placeholder
{
	return [[NameInputView alloc] initWithFrame:frame placeholder:placeholder];
}

- (NSString*)trimmedField:(NameInputView*)input fallback:(NSString*)fallback
{
	NSString* value = [[input.field.stringValue stringByTrimmingCharactersInSet:
		[NSCharacterSet whitespaceAndNewlineCharacterSet]] copy];
	if (value.length == 0)
		return fallback;
	return value;
}

- (NSString*)displayNameForMark:(char)mark
{
	return (mark == 'X') ? self.nameX : self.nameO;
}

- (NSString*)scoreSummaryText
{
	return [NSString stringWithFormat:@"X  %d       O  %d       Draw  %d",
		self.history->xWins(), self.history->oWins(), self.history->draws()];
}

- (NSString*)scoreHistoryText
{
	const std::deque<GameRecord>& recs = self.history->records();
	if (recs.empty())
		return @"No games yet";

	NSMutableString* line = [NSMutableString string];
	for (int i = (int)recs.size() - 1; i >= 0; --i)
	{
		const GameRecord& r = recs[i];
		NSString* mode = (r.mode == MODE_BOT) ? @"Bot" : @"2P";
		NSString* result = @"Draw";
		if (r.result != 'D')
			result = [NSString stringWithUTF8String:r.winnerName.c_str()];

		if (line.length > 0)
			[line appendString:@"   ·   "];
		[line appendFormat:@"#%d %@ → %@", r.number, mode, result];
	}
	return line;
}

- (void)addScorePanelAtTop
{
	CGFloat margin = 36.0;
	CGFloat panelW = self.viewW - margin * 2.0;
	CGFloat panelH = 92.0;
	CGFloat panelY = self.viewH - panelH - 28.0;

	ScorePanelView* panel = [[ScorePanelView alloc] initWithFrame:NSMakeRect(margin, panelY, panelW, panelH)];
	[self.view addSubview:panel];

	NSTextField* summary = [[NSTextField alloc] initWithFrame:NSMakeRect(margin + 16, panelY + 48, panelW - 32, 28)];
	summary.bezeled = NO;
	summary.editable = NO;
	summary.drawsBackground = NO;
	summary.alignment = NSTextAlignmentCenter;
	summary.font = [NSFont systemFontOfSize:16 weight:NSFontWeightSemibold];
	summary.textColor = textMuted();
	summary.stringValue = [self scoreSummaryText];
	self.scoreSummaryLabel = summary;
	[self.view addSubview:summary];

	self.scorePanel = [[NSTextField alloc] initWithFrame:NSMakeRect(margin + 16, panelY + 12, panelW - 32, 36)];
	self.scorePanel.bezeled = NO;
	self.scorePanel.editable = NO;
	self.scorePanel.drawsBackground = NO;
	self.scorePanel.alignment = NSTextAlignmentCenter;
	self.scorePanel.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightRegular];
	self.scorePanel.textColor = textDim();
	self.scorePanel.stringValue = [self scoreHistoryText];
	[self.view addSubview:self.scorePanel];
}

- (void)refreshScorePanel
{
	if (self.scoreSummaryLabel)
		self.scoreSummaryLabel.stringValue = [self scoreSummaryText];
	if (self.scorePanel)
		self.scorePanel.stringValue = [self scoreHistoryText];
}

- (void)buildMenuScreen
{
	CGFloat btnW = 280.0;
	CGFloat cx = centerX(self.viewW, btnW);

	[self.view addSubview:[self makeXOTitle:480 height:100 size:76]];
	[self.view addSubview:[self makeTitle:@"Tic-Tac-Toe" frame:NSMakeRect(0, 410, self.viewW, 36) size:22 color:textMuted()]];
	[self.view addSubview:[self makeButton:@"Start" frame:NSMakeRect(cx, 310, btnW, 56) action:@selector(goMode:)]];
	[self.view addSubview:[self makeTitle:@"Click to play" frame:NSMakeRect(0, 100, self.viewW, 28) size:15 color:textDim()]];
}

- (void)buildModeScreen
{
	CGFloat btnW = 300.0;
	CGFloat cx = centerX(self.viewW, btnW);

	[self.view addSubview:[self makeXOTitle:500 height:72 size:52]];
	[self.view addSubview:[self makeTitle:@"Choose mode" frame:NSMakeRect(0, 430, self.viewW, 44) size:28 color:textMuted()]];
	[self.view addSubview:[self makeButton:@"2 Players (1 Laptop)" frame:NSMakeRect(cx, 330, btnW, 56) action:@selector(startFriend:)]];
	[self.view addSubview:[self makeButton:@"Play vs Bot" frame:NSMakeRect(cx, 258, btnW, 56) action:@selector(startBot:)]];
	[self.view addSubview:[self makeButton:@"Back" frame:NSMakeRect(cx, 150, btnW, 56) action:@selector(goMenu:)]];
}

- (void)buildNamesScreen
{
	CGFloat fieldW = 360.0;
	CGFloat fieldH = 50.0;
	CGFloat cx = centerX(self.viewW, fieldW);
	CGFloat btnW = 280.0;
	CGFloat btnX = centerX(self.viewW, btnW);

	[self.view addSubview:[self makeXOTitle:510 height:72 size:48]];

	if (self.mode == MODE_BOT)
	{
		[self.view addSubview:[self makeTitle:@"Enter your name" frame:NSMakeRect(0, 430, self.viewW, 36) size:24 color:textMuted()]];
		self.nameInput1 = [self makeNameInput:NSMakeRect(cx, 352, fieldW, fieldH) placeholder:@"Your name"];
		[self.view addSubview:self.nameInput1];
	}
	else
	{
		[self.view addSubview:[self makeTitle:@"Enter player names" frame:NSMakeRect(0, 460, self.viewW, 36) size:24 color:textMuted()]];
		self.nameInput1 = [self makeNameInput:NSMakeRect(cx, 388, fieldW, fieldH) placeholder:@"Player 1 name"];
		[self.view addSubview:self.nameInput1];

		self.nameInput2 = [self makeNameInput:NSMakeRect(cx, 318, fieldW, fieldH) placeholder:@"Player 2 name"];
		[self.view addSubview:self.nameInput2];
	}

	[self.view addSubview:[self makeButton:@"Continue" frame:NSMakeRect(btnX, 180, btnW, 56) action:@selector(confirmNames:)]];
	[self.view addSubview:[self makeButton:@"Back" frame:NSMakeRect(btnX, 110, btnW, 56) action:@selector(goMode:)]];

	dispatch_async(dispatch_get_main_queue(), ^{
		[self.nameInput1 becomeFirstResponder];
	});
}

- (void)buildGameScreen
{
	[self addScorePanelAtTop];

	CGFloat statusY = self.viewH - 92.0 - 28.0 - 16.0 - 36.0;
	self.statusLabel = [self makeTitle:[self statusText] frame:NSMakeRect(0, statusY, self.viewW, 36) size:20 color:textMuted()];
	[self.view addSubview:self.statusLabel];

	CGFloat gridSize = 420.0;
	CGFloat startX = centerX(self.viewW, gridSize);
	CGFloat startY = 130.0;
	CGFloat cell = gridSize / 3.0;

	for (int i = 0; i < 9; ++i)
	{
		int row = i / 3;
		int col = i % 3;
		CGFloat x = startX + col * cell;
		CGFloat y = startY + (2 - row) * cell;

		CellButton* cellBtn = [[CellButton alloc] initWithFrame:NSMakeRect(x, y, cell, cell)];
		cellBtn.tag = i;
		cellBtn.owner = self;
		cellBtn.mark = self.engine->at(i);
		cellBtn.markAlpha = 1.0;
		cellBtn.markScale = 1.0;
		cellBtn.target = self;
		cellBtn.action = @selector(cellClicked:);
		[self.view addSubview:cellBtn];
		[self.cellButtons addObject:cellBtn];
	}

	CGFloat menuW = 200.0;
	[self.view addSubview:[self makeButton:@"Main Menu" frame:NSMakeRect(centerX(self.viewW, menuW), 48, menuW, 48) action:@selector(goMenu:)]];
}

- (NSString*)resultText
{
	if (self.engine->draw())
		return @"Draw";
	return [NSString stringWithFormat:@"%@ wins", [self displayNameForMark:self.engine->winner()]];
}

- (NSColor*)resultColor
{
	if (self.engine->draw())
		return textMuted();
	return (self.engine->winner() == 'X') ? brightX() : brightO();
}

- (void)buildOverScreen
{
	[self buildGameScreen];

	self.overOverlay = [[NSView alloc] initWithFrame:self.view.bounds];
	self.overOverlay.wantsLayer = YES;
	self.overOverlay.layer.backgroundColor = colorFromRGBA(0.02f, 0.03f, 0.06f, 0.72f).CGColor;
	self.overOverlay.alphaValue = 0.0;
	[self.view addSubview:self.overOverlay];

	self.resultLabel = [self makeTitle:[self resultText] frame:NSMakeRect(0, 420, self.viewW, 60) size:40 color:[self resultColor]];
	self.resultLabel.alphaValue = 0.0;
	self.resultLabel.layer.transform = CATransform3DMakeScale(0.7, 0.7, 1.0);
	[self.view addSubview:self.resultLabel];

	CGFloat btnW = 280.0;
	CGFloat cx = centerX(self.viewW, btnW);

	BrightButton* again = [self makeButton:@"Play Again" frame:NSMakeRect(cx, 310, btnW, 52) action:@selector(replay:)];
	again.alphaValue = 0.0;
	again.tag = 901;
	[self.view addSubview:again];

	BrightButton* menu = [self makeButton:@"Main Menu" frame:NSMakeRect(cx, 240, btnW, 52) action:@selector(goMenu:)];
	menu.alphaValue = 0.0;
	menu.tag = 902;
	[self.view addSubview:menu];

	[NSAnimationContext runAnimationGroup:^(NSAnimationContext* context) {
		context.duration = 0.45;
		self.overOverlay.animator.alphaValue = 1.0;
	} completionHandler:^{
		[NSAnimationContext runAnimationGroup:^(NSAnimationContext* context) {
			context.duration = 0.35;
			context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
			self.resultLabel.animator.alphaValue = 1.0;
			for (NSView* sub in self.view.subviews)
			{
				if (sub.tag == 901 || sub.tag == 902)
					sub.animator.alphaValue = 1.0;
			}
		} completionHandler:^{
			[NSAnimationContext runAnimationGroup:^(NSAnimationContext* context) {
				context.duration = 0.30;
				self.resultLabel.layer.transform = CATransform3DIdentity;
			} completionHandler:nil];
		}];
	}];
}

- (NSString*)statusText
{
	if (self.engine->over())
		return @"Game over";

	char current = self.engine->current();
	NSString* name = [self displayNameForMark:current];
	return [NSString stringWithFormat:@"%@'s turn  (%c)", name, current];
}

- (std::string)winnerNameForHistory
{
	if (self.engine->draw())
		return "Draw";
	return std::string([[self displayNameForMark:self.engine->winner()] UTF8String]);
}

- (void)recordResult
{
	self.history->add(self.mode, self.engine->winner(), self.engine->draw(), [self winnerNameForHistory]);
	[self refreshScorePanel];
}

- (void)lockCells
{
	self.inputLocked = YES;
	for (CellButton* btn in self.cellButtons)
	{
		btn.interactionEnabled = NO;
		[btn clearPreview];
	}
}

- (void)runFinishAnimation
{
	[self lockCells];

	if (self.engine->hasWinLine())
	{
		for (CellButton* btn in self.cellButtons)
		{
			if (self.engine->isWinningCell((int)btn.tag))
				btn.isWinningCell = YES;
		}

		__block CGFloat pulse = 0.0;
		self.finishTimer = [NSTimer scheduledTimerWithTimeInterval:0.016 repeats:YES block:^(NSTimer* t) {
			(void)t;
			pulse += 0.016f;
			for (CellButton* btn in self.cellButtons)
			{
				if (btn.isWinningCell)
				{
					btn.winPulse = pulse;
					[btn setNeedsDisplay:YES];
				}
			}
		}];

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[self.finishTimer invalidate];
			self.finishTimer = nil;
			[self recordResult];
			self.screen = SCREEN_OVER;
			[self buildUI];
		});
	}
	else
	{
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			[self recordResult];
			self.screen = SCREEN_OVER;
			[self buildUI];
		});
	}
}

- (CellButton*)cellAtIndex:(int)index
{
	for (CellButton* btn in self.cellButtons)
	{
		if ((int)btn.tag == index)
			return btn;
	}
	return nil;
}

- (void)afterMoveFromCell:(int)pos
{
	if (self.engine->over())
	{
		self.statusLabel.stringValue = [self statusText];
		[self runFinishAnimation];
		return;
	}

	self.statusLabel.stringValue = [self statusText];

	if (self.mode == MODE_BOT && !self.engine->over())
	{
		self.inputLocked = YES;
		for (CellButton* btn in self.cellButtons)
			[btn clearPreview];

		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.40 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			int move = self.engine->botMove();
			if (move >= 0)
			{
				self.engine->play(move);
				CellButton* botCell = [self cellAtIndex:move];
				if (botCell)
				{
					[botCell animatePlaceMark:'O' completion:^{
						if (self.engine->over())
						{
							self.statusLabel.stringValue = [self statusText];
							[self runFinishAnimation];
						}
						else
						{
							self.inputLocked = NO;
							self.statusLabel.stringValue = [self statusText];
						}
					}];
				}
				else if (self.engine->over())
				{
					[self runFinishAnimation];
				}
				else
				{
					self.inputLocked = NO;
				}
			}
			else
			{
				self.inputLocked = NO;
			}
		});
	}
}

- (void)goMenu:(id)sender
{
	(void)sender;
	self.screen = SCREEN_MENU;
	self.engine->reset();
	[self buildUI];
}

- (void)goMode:(id)sender
{
	(void)sender;
	self.screen = SCREEN_MODE;
	[self buildUI];
}

- (void)startFriend:(id)sender
{
	(void)sender;
	self.mode = MODE_FRIEND;
	self.screen = SCREEN_NAMES;
	[self buildUI];
}

- (void)startBot:(id)sender
{
	(void)sender;
	self.mode = MODE_BOT;
	self.screen = SCREEN_NAMES;
	[self buildUI];
}

- (void)confirmNames:(id)sender
{
	(void)sender;

	if (self.mode == MODE_BOT)
	{
		self.nameX = [self trimmedField:self.nameInput1 fallback:@"You"];
		self.nameO = @"Bot";
	}
	else
	{
		self.nameX = [self trimmedField:self.nameInput1 fallback:@"Player 1"];
		self.nameO = [self trimmedField:self.nameInput2 fallback:@"Player 2"];
	}

	self.engine->reset();
	self.screen = SCREEN_GAME;
	[self buildUI];
}

- (void)replay:(id)sender
{
	(void)sender;
	self.engine->reset();
	self.screen = SCREEN_GAME;
	[self buildUI];
}

- (void)cellClicked:(CellButton*)sender
{
	if (self.inputLocked || self.engine->over())
		return;

	if (self.mode == MODE_BOT && self.engine->current() == 'O')
		return;

	int pos = (int)sender.tag;
	if (self.engine->at(pos) != ' ')
		return;

	char placed = self.engine->current();
	if (!self.engine->play(pos))
		return;

	[sender animatePlaceMark:placed completion:^{
		[self afterMoveFromCell:pos];
	}];
}

@end

@interface AppDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property (nonatomic, strong) NSWindow* window;
@property (nonatomic, strong) GameViewController* controller;
@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification*)notification
{
	(void)notification;

	[NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];

	NSRect frame = NSMakeRect(0, 0, 720, 760);
	self.window = [[NSWindow alloc] initWithContentRect:frame
		styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable)
		backing:NSBackingStoreBuffered defer:NO];
	[self.window setTitle:@"X / O"];
	self.window.delegate = self;
	self.window.releasedWhenClosed = NO;
	[self.window center];

	self.controller = [[GameViewController alloc] init];
	self.window.contentViewController = self.controller;
	[self.window makeKeyAndOrderFront:nil];
	[NSApp activateIgnoringOtherApps:YES];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)sender
{
	(void)sender;
	return YES;
}

- (void)windowWillClose:(NSNotification*)notification
{
	(void)notification;
	[self.controller.finishTimer invalidate];
	[NSApp terminate:nil];
}

@end

int main(int argc, const char* argv[])
{
	(void)argc;
	(void)argv;

	@autoreleasepool
	{
		srand((unsigned)time(NULL));
		NSApplication* app = [NSApplication sharedApplication];
		AppDelegate* delegate = [[AppDelegate alloc] init];
		app.delegate = delegate;
		[app run];
	}
	return 0;
}
