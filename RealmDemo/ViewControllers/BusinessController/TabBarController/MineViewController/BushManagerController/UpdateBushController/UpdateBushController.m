//
//  UpdateBushController.m
//  RealmDemo
//
//  Created by lottak_mac2 on 16/7/15.
//  Copyright © 2016年 com.luohaifang. All rights reserved.
//

#import "UpdateBushController.h"
#import "Company.h"
#import "UserHttp.h"
#import "UserManager.h"
//名称最长多少字符
#define MAX_STARWORDS_LENGTH 20

@interface UpdateBushController ()<UINavigationControllerDelegate, UIImagePickerControllerDelegate> {
    UserManager *_userManager;//用户管理器
    Company *_currCompany;//当前圈子，是一个拷贝的东西
    UIImage *_currCompanyImage;//圈子的图标，如果有值，表示将要修改图标，没有值，表示用户没有选择
}

@property (weak, nonatomic) IBOutlet UILabel *companyName;
@property (weak, nonatomic) IBOutlet UILabel *companyType;
@property (weak, nonatomic) IBOutlet UIImageView *companyImage;
@property (weak, nonatomic) IBOutlet UILabel *companyOwner;
@property (weak, nonatomic) IBOutlet UILabel *companyOwnerPhone;

@end

@implementation UpdateBushController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"修改圈子";
    _userManager = [UserManager manager];
    self.tableView.tableFooterView = [UIView new];
    //给予初始值
    self.companyName.text = _currCompany.company_name;
    self.companyType.text = [_currCompany companyTypeStr];
    [self.companyImage sd_setImageWithURL:[NSURL URLWithString:_currCompany.logo] placeholderImage:[UIImage imageNamed:@"default_image_icon"]];
    //获取圈主
    Employee *employee = [_userManager getEmployeeWithGuid:_currCompany.admin_user_guid companyNo:_currCompany.company_no];
    self.companyOwner.text = employee.real_name;
    self.companyOwnerPhone.text = employee.email;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(rightButtonClicked:)];
    //确定按钮是否能够被点击
    RACSignal *nameSignal = RACObserve(_currCompany, company_name);
    RAC(self.navigationItem.rightBarButtonItem,enabled) = [nameSignal map:^(NSString* name) {
        if([NSString isBlank:name])
            return @(NO);
        return @(YES);
    }];
}
- (void)dataDidChange {
    _currCompany = [self.data deepCopy];
}
- (void)rightButtonClicked:(UIBarButtonItem*)item {
    //有图片就要上传图片 然后得到url再修改
    if(_currCompanyImage) {
        [self.navigationController.view showLoadingTips:@""];
        [UserHttp updateConpanyAvater:_currCompanyImage companyNo:_currCompany.company_no userGuid:_userManager.user.user_guid handler:^(id data, MError *error) {
            if(error) {
                [self.navigationController.view dismissTips];
                [self.navigationController.view showFailureTips:error.statsMsg];
                return ;
            }
            _currCompany.logo = data[@"data"][@"logo"];
            [UserHttp updateCompany:_currCompany.company_no companyName:_currCompany.company_name companyType:_currCompany.company_type logo:_currCompany.logo handler:^(id data, MError *error) {
                [self.navigationController.view dismissTips];
                if(error) {
                    [self.navigationController.view showFailureTips:error.statsMsg];
                    return ;
                }
                [_userManager updateCompany:_currCompany];
                if(_currCompany.company_no == _userManager.user.currCompany.company_no) {
                    _userManager.user.currCompany = _currCompany;
                    [_userManager updateUser:_userManager.user];
                }
                //改变圈子详情的内容
                Company *company = self.data;
                company.company_name = _currCompany.company_name;
                company.company_type = _currCompany.company_type;
                company.logo = _currCompany.logo;
                [self.navigationController popViewControllerAnimated:YES];
            }];
        }];
    } else {
        [self.navigationController.view showLoadingTips:@""];
        [UserHttp updateCompany:_currCompany.company_no companyName:_currCompany.company_name companyType:_currCompany.company_type logo:_currCompany.logo handler:^(id data, MError *error) {
            [self.navigationController.view dismissTips];
            if(error) {
                [self.navigationController.view showFailureTips:error.statsMsg];
                return ;
            }
            [_userManager updateCompany:_currCompany];
            //改变圈子详情的内容
            Company *company = self.data;
            company.company_name = _currCompany.company_name;
            company.company_type = _currCompany.company_type;
            company.logo = _currCompany.logo;
            [self.navigationController popViewControllerAnimated:YES];
        }];
    }
}
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if(indexPath.row == 0) {
        UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"圈子名称" message:nil preferredStyle:UIAlertControllerStyleAlert];
        [alertVC addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
            //#BANG-577 圈子名字要限制长度
            [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(textFiledEditChanged:) name:@"UITextFieldTextDidChangeNotification" object:textField];
            textField.placeholder = @"请输入名称...";
            textField.text = _currCompany.company_name;
        }];
        UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"确认" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            UITextField *field = alertVC.textFields[0];
            _currCompany.company_name = field.text;
            self.companyName.text = field.text;
        }];
        UIAlertAction *cancleActio = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
        [alertVC addAction:cancleActio];
        [alertVC addAction:okAction];
        [self presentViewController:alertVC animated:YES completion:nil];
    } else if (indexPath.row == 1) {
        //选择圈子类型
        UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"圈子类型" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction *cacleAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
        UIAlertAction *selectAction1 = [UIAlertAction actionWithTitle:@"国有企业" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            _currCompany.company_type = 1;
            self.companyType.text = [_currCompany companyTypeStr];
        }];
        UIAlertAction *selectAction2 = [UIAlertAction actionWithTitle:@"私有企业" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            _currCompany.company_type = 2;
            self.companyType.text = [_currCompany companyTypeStr];
        }];
        UIAlertAction *selectAction3 = [UIAlertAction actionWithTitle:@"事业单位或社会团体" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            _currCompany.company_type = 3;
            self.companyType.text = [_currCompany companyTypeStr];
        }];
        UIAlertAction *selectAction4 = [UIAlertAction actionWithTitle:@"中外合资" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            _currCompany.company_type = 4;
            self.companyType.text = [_currCompany companyTypeStr];
        }];
        UIAlertAction *selectAction5 = [UIAlertAction actionWithTitle:@"外商独资" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            _currCompany.company_type = 5;
            self.companyType.text = [_currCompany companyTypeStr];
        }];
        UIAlertAction *selectAction6 = [UIAlertAction actionWithTitle:@"其他" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            _currCompany.company_type = 6;
            self.companyType.text = [_currCompany companyTypeStr];
        }];
        [alertVC addAction:cacleAction];
        [alertVC addAction:selectAction1];
        [alertVC addAction:selectAction2];
        [alertVC addAction:selectAction3];
        [alertVC addAction:selectAction4];
        [alertVC addAction:selectAction5];
        [alertVC addAction:selectAction6];
        [self presentViewController:alertVC animated:YES completion:nil];
    } else if(indexPath.row == 2) {
        //选择圈子图标
        UIAlertController *alertVC = [UIAlertController alertControllerWithTitle:@"上传图标" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
        UIAlertAction *cacleAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
        UIAlertAction *selectAction = [UIAlertAction actionWithTitle:@"选取相册图片" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            UIImagePickerController * picker = [[UIImagePickerController alloc] init];
            picker.delegate = self;
            picker.allowsEditing = YES;
            picker.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
            [self presentViewController:picker animated:YES completion:nil];
        }];
        UIAlertAction *creamAction = [UIAlertAction actionWithTitle:@"现在拍摄" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            UIImagePickerController * picker = [[UIImagePickerController alloc] init];
            picker.delegate = self;
            picker.allowsEditing = YES;
            if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {//看当前设备是否能够拍照
                picker.sourceType = UIImagePickerControllerSourceTypeCamera;
            } else {
                [self.navigationController.view showFailureTips:@"无法打开相机"];
            }
            [self presentViewController:picker animated:YES completion:nil];
        }];
        [alertVC addAction:cacleAction];
        [alertVC addAction:selectAction];
        [alertVC addAction:creamAction];
        [self presentViewController:alertVC animated:YES completion:nil];
    }
}
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(nullable NSDictionary<NSString *,id> *)editingInfo {
    _currCompanyImage = image;
    self.companyImage.image = image;
    [picker dismissViewControllerAnimated:YES completion:nil];
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}
#pragma mark --
#pragma mark -- TextFieldDelegate
-(void)textFiledEditChanged:(NSNotification *)obj
{
    UITextField *textField = (UITextField *)obj.object;
    NSString *toBeString = textField.text;
    NSString *lang = [textField.textInputMode primaryLanguage];
    if ([lang isEqualToString:@"zh-Hans"]){// 简体中文输入
        //获取高亮部分
        UITextRange *selectedRange = [textField markedTextRange];
        UITextPosition *position = [textField positionFromPosition:selectedRange.start offset:0];
        // 没有高亮选择的字，则对已输入的文字进行字数统计和限制
        if (!position) {
            if (toBeString.length > MAX_STARWORDS_LENGTH) {
                [self.navigationController.view showMessageTips:@"圈子名称不能大于20个字"];
                textField.text = [toBeString substringToIndex:MAX_STARWORDS_LENGTH];
            }
        }
    } else {// 中文输入法以外的直接对其统计限制即可，不考虑其他语种情况
        if (toBeString.length > MAX_STARWORDS_LENGTH) {
            [self.navigationController.view showMessageTips:@"圈子名称不能大于20个字"];
            NSRange rangeIndex = [toBeString rangeOfComposedCharacterSequenceAtIndex:MAX_STARWORDS_LENGTH];
            if (rangeIndex.length == 1) {
                textField.text = [toBeString substringToIndex:MAX_STARWORDS_LENGTH];
            } else {
                NSRange rangeRange = [toBeString rangeOfComposedCharacterSequencesForRange:NSMakeRange(0, MAX_STARWORDS_LENGTH)];
                textField.text = [toBeString substringWithRange:rangeRange];
            }
        }
    }
}
@end
