from rest_framework_simplejwt.authentication import JWTAuthentication
from rest_framework_simplejwt.exceptions import InvalidToken


class PasswordVersionJWTAuthentication(JWTAuthentication):

    def get_user(self, validated_token):
        user = super().get_user(validated_token)

        token_auth_version = validated_token.get("auth_version")

        if token_auth_version != user.auth_version:
            raise InvalidToken({
                "detail": (
                    "Your session is no longer valid. "
                    "Please sign in again."
                ),
                "code": "token_not_valid",
            })

        return user