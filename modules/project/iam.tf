/**
 * Copyright 2025 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

# tfdoc:file:description IAM bindings.

# IAM notes:
# - external users need to have accepted the invitation email to join

locals {
  _custom_roles_path = pathexpand(coalesce(var.factories_config.custom_roles, "-"))
  _custom_roles = {
    for f in try(fileset(local._custom_roles_path, "*.yaml"), []) :
    replace(f, ".yaml", "") => yamldecode(
      file("${local._custom_roles_path}/${f}")
    )
  }
  _iam_principal_roles = distinct(flatten(values(var.iam_by_principals)))
  _iam_principals = {
    for r in local._iam_principal_roles : r => [
      for k, v in var.iam_by_principals :
      k if try(index(v, r), null) != null
    ]
  }
  custom_roles = merge(
    {
      for k, v in local._custom_roles : k => {
        name        = lookup(v, "name", k)
        permissions = v["includedPermissions"]
      }
    },
    {
      for k, v in var.custom_roles : k => {
        name        = k
        permissions = v
      }
    }
  )
  iam = {
    for role in distinct(concat(keys(var.iam), keys(local._iam_principals))) :
    role => concat(
      try(var.iam[role], []),
      try(local._iam_principals[role], [])
    )
  }
  iam_bindings_additive = merge(
    var.iam_bindings_additive,
    [
      for principal, roles in var.iam_by_principals_additive : {
        for role in roles :
        "iam-bpa:${principal}-${role}" => {
          member    = principal
          role      = role
          condition = null
        }
      }
    ]...
  )
}

# we use a different key for custom roles to allow referring to the role alias
# in Terraform, while still being able to define unique role names

check "custom_roles" {
  assert {
    condition = (
      length(local.custom_roles) == length({
        for k, v in local.custom_roles : v.name => null
      })
    )
    error_message = "Duplicate role name in custom roles."
  }
}

resource "google_project_iam_custom_role" "roles" {
  for_each    = local.custom_roles
  project     = local.project.project_id
  role_id     = each.value.name
  title       = "Custom role ${each.value.name}"
  description = "Terraform-managed."
  permissions = each.value.permissions
}

resource "google_project_iam_binding" "authoritative" {
  for_each = local.iam
  project  = local.project.project_id
  role     = each.key
  members  = each.value
  depends_on = [
    google_project_service.project_services,
    google_project_iam_custom_role.roles
  ]
}

resource "google_project_iam_binding" "bindings" {
  for_each = var.iam_bindings
  project  = local.project.project_id
  role     = each.value.role
  members  = each.value.members
  dynamic "condition" {
    for_each = each.value.condition == null ? [] : [""]
    content {
      expression  = each.value.condition.expression
      title       = each.value.condition.title
      description = each.value.condition.description
    }
  }
  depends_on = [
    google_project_service.project_services,
    google_project_iam_custom_role.roles
  ]
}

resource "google_project_iam_member" "bindings" {
  for_each = local.iam_bindings_additive
  project  = local.project.project_id
  role     = each.value.role
  member   = each.value.member
  dynamic "condition" {
    for_each = each.value.condition == null ? [] : [""]
    content {
      expression  = each.value.condition.expression
      title       = each.value.condition.title
      description = each.value.condition.description
    }
  }
  depends_on = [
    google_project_service.project_services,
    google_project_iam_custom_role.roles
  ]
}
