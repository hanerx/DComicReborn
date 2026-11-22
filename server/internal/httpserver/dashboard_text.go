package httpserver

import (
	"errors"

	"dcomic-sync-server/internal/store"
)

func dashboardCategoryLabel(category string) string {
	switch category {
	case "history":
		return "阅读历史与订阅"
	case "bindings":
		return "漫画源绑定"
	case "chapterRules":
		return "章节匹配规则"
	case "settings":
		return "应用设置"
	case "sourceSettings":
		return "漫画源设置"
	case "credentials":
		return "令牌与 Cookie"
	default:
		return category
	}
}

func dashboardDeviceName(name, deviceID string) string {
	if deviceID == "server-dashboard" {
		return "服务器后台"
	}
	name = store.DeviceDisplayName(name, deviceID)
	if name == "Unknown device" {
		return "未知设备"
	}
	return name
}

// Translate at the web boundary; API errors and stored sync data stay unchanged.
func (s *Server) dashboardError(err error) string {
	var appErr *store.Error
	if errors.As(err, &appErr) {
		switch appErr.Code {
		case store.CodeBadRequest:
			switch appErr.Message {
			case "username must be 3-64 characters using letters, numbers, '.', '_' or '-'":
				return "用户名须为 3–64 个字符，只能使用英文字母、数字、点、下划线或连字符。"
			case "password must be 12-72 bytes":
				return "密码长度须为 12–72 个 UTF-8 字节。"
			default:
				return "请求参数无效，请检查后重试。"
			}
		case store.CodeConflict, store.CodeVersionReuse:
			switch appErr.Message {
			case "username already exists":
				return "用户名已存在，请使用其他用户名。"
			case "an administrator already exists":
				return "管理员已创建，请前往登录页面。"
			default:
				return "数据已被其他设备修改或处理，请刷新页面后重试。"
			}
		case store.CodeNotFound:
			switch appErr.Message {
			case "user not found":
				return "用户不存在。"
			case "active device not found":
				return "设备会话已失效或不存在。"
			default:
				return "记录或冲突已不存在，可能已由其他设备处理，请刷新页面。"
			}
		case store.CodeUnauthorized:
			return "登录已失效，请重新登录。"
		case store.CodeForbidden:
			return "没有执行此操作的权限。"
		case store.CodeFutureClock:
			return "记录时间超出允许范围，请检查设备时钟。"
		}
	}
	s.logger.Error("dashboard operation failed", "error", err)
	return "服务器内部错误，请稍后重试。"
}
