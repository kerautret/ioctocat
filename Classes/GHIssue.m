#import "GHIssue.h"
#import "GHIssueComment.h"
#import "GHIssueComments.h"
#import "GHRepository.h"
#import "GHMilestone.h"
#import "GHLabels.h"
#import "GHUser.h"
#import "iOctocat.h"
#import "NSString+Extensions.h"
#import "NSDictionary+Extensions.h"


@implementation GHIssue

- (id)initWithRepository:(GHRepository *)repo {
	self = [super init];
	if (self) {
		self.repository = repo;
		self.state = kIssueStateOpen;
	}
	return self;
}

- (BOOL)isNew {
	return !self.number ? YES : NO;
}

- (BOOL)isOpen {
	return [self.state isEqualToString:kIssueStateOpen];
}

- (NSString *)resourcePath {
	// Dynamic resourcePath, because it depends on the
	// num which isn't always available in advance
	return [NSString stringWithFormat:kIssueFormat, self.repository.owner, self.repository.name, self.number];
}

- (GHIssueComments *)comments {
    if (!_comments) {
        _comments = [[GHIssueComments alloc] initWithParent:self];
    }
    return _comments;
}

#pragma mark Loading

- (void)setValues:(id)dict {
	NSString *userLogin = [dict safeStringForKeyPath:@"user.login"];
	NSString *assigneeLogin = [dict safeStringForKeyPath:@"assignee.login"];
	self.user = [iOctocat.sharedInstance userWithLogin:userLogin];
	self.assignee = [iOctocat.sharedInstance userWithLogin:assigneeLogin];
	self.createdAt = [dict safeDateForKey:@"created_at"];
	self.updatedAt = [dict safeDateForKey:@"updated_at"];
	self.closedAt = [dict safeDateForKey:@"closed_at"];
	self.title = [dict safeStringForKey:@"title"];
	self.body = [dict safeStringForKey:@"body"];
	self.state = [dict safeStringForKey:@"state"];
	self.number = [dict safeIntegerForKey:@"number"];
	self.htmlURL = [dict safeURLForKey:@"html_url"];
    // repo
	if (!self.repository) {
		NSString *owner = [dict safeStringForKeyPath:@"repository.owner.login"];
		NSString *name = [dict safeStringForKeyPath:@"repository.name"];
		if (!owner.isEmpty && !name.isEmpty) {
			self.repository = [[GHRepository alloc] initWithOwner:owner andName:name];
		}
	}
    // labels
    NSArray *labels = [dict safeArrayForKey:@"labels"];
    self.labels = [[GHLabels alloc] initWithRepository:self.repository];
    [self.labels setValues:labels];
    // milestone
    NSDictionary *milestoneDict = [dict safeDictForKey:@"milestone"];
    self.milestone = [[GHMilestone alloc] initWithRepository:self.repository];
    [self.milestone setValues:milestoneDict];
}

#pragma mark Saving

- (void)saveWithParams:(NSDictionary *)params start:(resourceStart)start success:(resourceSuccess)success failure:(resourceFailure)failure {
	NSString *path = nil;
	NSString *method = nil;
	if (self.isNew) {
		path = [NSString stringWithFormat:kIssueOpenFormat, self.repository.owner, self.repository.name];
		method = kRequestMethodPost;
	} else {
		path = [NSString stringWithFormat:kIssueEditFormat, self.repository.owner, self.repository.name, self.number];
		method = kRequestMethodPatch;
	}
	[self saveWithParams:params path:path method:method start:start success:^(GHResource *instance, id data) {
		[self setValues:data];
		if (success) success(self, data);
	} failure:^(GHResource *instance, NSError *error) {
		if (failure) failure(self, error);
	}];
}

@end